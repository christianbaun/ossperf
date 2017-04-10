#!/bin/bash
#
# title:        s3perf.sh
# description:  This script analyzes the performance and data integrity of 
#               S3-compatible storage services 
# author:       Dr. Christian Baun, Rosa Maria Spanou
# url:          https://github.com/christianbaun/s3perf
# license:      GPLv3
# date:         April 11th 2017
# version:      1.51
# bash_version: 4.3.30(1)-release
# requires:     md5sum (tested with version 8.23),
#               bc (tested with version 1.06.95),
#               s3cmd (tested with versions 1.5.0 and 1.6.1),
#               parallel (tested with version 20130922)
# notes:        s3cmd need to be configured first via s3cmd --configure
# example:      ./s3perf.sh -n 5 -s 1048576 # 5 files of 1 MB size each
# ----------------------------------------------------------------------------

# Check if the required command line tools are available
command -v s3cmd >/dev/null 2>&1 || { echo >&2 "s3perf requires the command line tool s3cmd. Please install it."; exit 1; }
command -v bc >/dev/null 2>&1 || { echo >&2 "s3perf requires the command line tool bc. Please install it."; exit 1; }
command -v md5sum >/dev/null 2>&1 || { echo >&2 "s3perf requires the command line tool md5sum. Please install it."; exit 1; }
command -v ping >/dev/null 2>&1 || { echo >&2 "s3perf requires the command line tool ping Please install it."; exit 1; }

function usage
{
echo "$SCRIPT -n files -s size [-u] [-k] [-p]

This script analyzes the performance and data integrity of S3-compatible
storage services 

Arguments:
-h : show this message on screen
-n : number of files to be created
-s : size of the files to be created in bytes (max 16777216 = 16 MB)
-u : use upper-case letters for the bucket name (this is required for Nimbus Cumulus)
-k : keep the local files and the directory afterwards (do not clean up)
-p : upload and download the files in parallel
"
exit 0
}

SCRIPT=${0##*/}   # script name
NUM_FILES=
SIZE_FILES=
UPPERCASE=0
NOT_CLEAN_UP=0
PARALLEL=0
LIST_OF_FILES=


while getopts "hn:s:ukp" Arg ; do
  case $Arg in
    h) usage ;;
    n) NUM_FILES=$OPTARG ;;
    s) SIZE_FILES=$OPTARG ;;
    # If the flag has been set => $NOT_CLEAN_UP gets value 1
    u) UPPERCASE=1 ;;
    k) NOT_CLEAN_UP=1 ;;
    p) PARALLEL=1 ;;
    \?) echo "Invalid option: $OPTARG" >&2
        exit 1
        ;;
  esac
done


# Only if the user wants to execute the upload and dowload of the files in parallel...
if [ "$PARALLEL" -eq 1 ] ; then
  # ... the script needs to check, if the command line tool GNU parallel is installed
  command -v parallel >/dev/null 2>&1 || { echo >&2 "s3perf requires the command line tool parallel. Please install it."; exit 1; }
fi

# Path of the directory for the files
DIRECTORY="testfiles"
# Name for the bucket to store the files
# ATTENTION! When using Google Cloud Storage or Amazon S3, it is ok when the bucket name is written in lower case.
# But when using Nimbus Cumulus, the bucket name needs to be in upper case.
# Minio does not accept bucket names with upper-case letters.
# 
# A helpful source about this topic is: http://docs.rightscale.com/faq/clouds/aws/What_are_valid_S3_bucket_names.html
# "In order to conform with DNS requirements, we recommend following these additional guidelines when creating buckets:"
# "Bucket names should not contain upper-case letters"
# "Bucket names should not contain underscores (_)"
# "Bucket names should not end with a dash"
# "Bucket names should be between 3 and 63 characters long"
# "Bucket names cannot contain dashes next to periods (e.g., my-.bucket.com and my.-bucket are invalid)"
# "Bucket names cannot contain periods"

if [[ "UPPERCASE" -eq 1 ]] ; then
   BUCKET="S3PERF-TESTBUCKET"
else
   BUCKET="s3perf-testbucket"
fi

if ([[ "$NUM_FILES" -eq 0 ]] || [[ "$SIZE_FILES" -eq 0 ]] || [[ "$SIZE_FILES" -gt 16777216 ]]) ; then
   usage
   exit 1
fi

# Check if we have a working network connection by sending a ping to 8.8.8.8
if ping -q -c 1 -W 1 8.8.8.8 >/dev/null ; then
  echo "This computer has a working internet connection."
else
  echo "This computer has no working internet connection. Please check your network settings." && exit 1
fi

# Check if the directory already exists
# This is not a part of the benchmark!
if [ -e ${DIRECTORY} ] ; then
  # Terminate the script, in case the directory already exists
  echo "The directory ${DIRECTORY} already exists!" && exit 1
else
  if mkdir ${DIRECTORY} ; then
    # Create the directory if it does not already exist
    echo "The directory ${DIRECTORY} has been created."
  else
    echo "Unable to create the directory ${DIRECTORY}" && exit 1
  fi
fi

# Create files with random content of given size
# This is not a part of the benchmark!
for ((i=1; i<=${NUM_FILES}; i+=1))
do
  if dd if=/dev/urandom of=$DIRECTORY/s3perf-testfile$i.txt bs=1 count=$SIZE_FILES ; then
    echo "Files with random content have been created."
  else
    echo "Unable to create the files." && exit 1
  fi
done

# Calculate the checksums of the files
# This is not a part of the benchmark!
if md5sum $DIRECTORY/* > $DIRECTORY/MD5SUM ; then
  echo "Checksums have been calculated and MD5SUM file has been created."
else
  echo "Unable to calculate the checksums and create the MD5SUM file." && exit 1
fi


# Start of the 1st time measurement
TIME_CREATE_BUCKET_START=`date +%s.%N`

# Create bucket
if s3cmd mb s3://$BUCKET ; then
  echo "Bucket ${BUCKET} has been created."
else
  echo "Unable to create the bucket ${BUCKET}." && exit 1
fi

# End of the 1st time measurement
TIME_CREATE_BUCKET_END=`date +%s.%N`

# Duration of the 1st time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_CREATE_BUCKET=`echo "scale=3 ; (${TIME_CREATE_BUCKET_END} - ${TIME_CREATE_BUCKET_START})/1" | bc | sed 's/^\./0./'`


# Start of the 2nd time measurement
TIME_OBJECTS_UPLOAD_START=`date +%s.%N`

# If the "parallel" flag has been set, upload in parallel with GNU parallel
if [ "$PARALLEL" -eq 1 ] ; then
  # Upload files in parallel
  if find $DIRECTORY/*.txt | parallel s3cmd put {} s3://$BUCKET ; then
    echo "Files have been uploaded."
  else
    echo "Unable to upload the files." && exit 1
  fi
else
  # Upload files sequentially
  if s3cmd put $DIRECTORY/*.txt s3://$BUCKET ; then
    echo "Files have been uploaded."
  else
    echo "Unable to upload the files." && exit 1
  fi
fi

# End of the 2nd time measurement
TIME_OBJECTS_UPLOAD_END=`date +%s.%N`

# Duration of the 2nd time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_OBJECTS_UPLOAD=`echo "scale=3 ; (${TIME_OBJECTS_UPLOAD_END} - ${TIME_OBJECTS_UPLOAD_START})/1" | bc | sed 's/^\./0./'`


# Wait a moment. Sometimes, the services cannot provide fresh uploaded files this quick
sleep 1

# Start of the 3rd time measurement
TIME_OBJECTS_DOWNLOAD_START=`date +%s.%N`

echo ${LIST_OF_FILES}

# If the "parallel" flag has been set, download in parallel with GNU parallel
if [ "$PARALLEL" -eq 1 ] ; then
  # Download files in parallel
  if find ${DIRECTORY}/*.txt -type f -printf "%f\n" | parallel s3cmd get --force s3://$BUCKET/{} $DIRECTORY/ ; then
    echo "Files have been downloaded."
  else
    echo "Unable to download the files." && exit 1
  fi
else
  # Download files sequentially
  if s3cmd get --force s3://$BUCKET/*.txt $DIRECTORY/ ; then
    echo "Files have been downloaded."
  else
    echo "Unable to download the files." && exit 1
  fi
fi

# End of the 3rd time measurement
TIME_OBJECTS_DOWNLOAD_END=`date +%s.%N`

# Duration of the 3rd time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_OBJECTS_DOWNLOAD=`echo "scale=3 ; (${TIME_OBJECTS_DOWNLOAD_END} - ${TIME_OBJECTS_DOWNLOAD_START})/1" | bc | sed 's/^\./0./'`


# Validate the checksums of the files
# This is not a part of the benchmark!
if md5sum -c $DIRECTORY/MD5SUM ; then
  echo "Checksums have been validated and match the files."
else
  echo "The checksums do not match the files." && exit 1
fi


# Start of the 4th time measurement
TIME_ERASE_OBJECTS_START=`date +%s.%N`

# Erase files (objects) inside the bucket
if s3cmd del s3://$BUCKET/* ; then
  echo "Files inside the bucket ${BUCKET} have been erased"
else
  echo "Unable to erase the files inside the bucket ${BUCKET}." && exit 1
fi

# End of the 4th time measurement
TIME_ERASE_OBJECTS_END=`date +%s.%N`

# Duration of the 4th time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_ERASE_OBJECTS=`echo "scale=3 ; (${TIME_ERASE_OBJECTS_END} - ${TIME_ERASE_OBJECTS_START})/1" | bc | sed 's/^\./0./'`


# Start of the 5th time measurement
TIME_ERASE_BUCKET_START=`date +%s.%N`

# Erase bucket
if s3cmd rb s3://$BUCKET ; then
  echo "Bucket ${BUCKET} has been erased."
else
  echo "Unable to erase the bucket ${BUCKET}." && exit 1
fi

# End of the 5th time measurement
TIME_ERASE_BUCKET_END=`date +%s.%N`

# Duration of the 5th time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_ERASE_BUCKET=`echo "scale=3 ; (${TIME_ERASE_BUCKET_END} - ${TIME_ERASE_BUCKET_START})/1" | bc | sed 's/^\./0./'`

# If the "not clean up" flag has not been set, erase the local directory with the files
if [ "$NOT_CLEAN_UP" -ne 1 ] ; then
  # Erase the local directory with the files
  if rm -rf $DIRECTORY ; then
    echo "The directory ${DIRECTORY} has been erased"
  else
    echo "Unable to erase the directory ${DIRECTORY}" && exit 1
  fi
fi

echo 'Required time to create the bucket:                 '${TIME_CREATE_BUCKET}s
echo 'Required time to upload the files:                  '${TIME_OBJECTS_UPLOAD}s
echo 'Required time to download the files:                '${TIME_OBJECTS_DOWNLOAD}s
echo 'Required time to erase the objects:                 '${TIME_ERASE_OBJECTS}s
echo 'Required time to erase the bucket:                  '${TIME_ERASE_BUCKET}s

TIME_SUM=`echo "scale=3 ; (${TIME_CREATE_BUCKET} + ${TIME_OBJECTS_UPLOAD} + ${TIME_OBJECTS_DOWNLOAD} + ${TIME_ERASE_OBJECTS} + ${TIME_ERASE_BUCKET})/1" | bc | sed 's/^\./0./'`

echo 'Required time to perform all S3-related operations: '${TIME_SUM}s
