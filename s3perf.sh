#!/bin/bash
#
# title:        s3perf.sh
# description:  This script analyzes the performance and data integrity of 
#               S3-compatible storage services 
# author:       Dr. Christian Baun, Rosa Maria Spanou, Marius Wernicke
# url:          https://github.com/christianbaun/s3perf
# license:      GPLv3
# date:         August 29th 2017
# version:      2.6
# bash_version: 4.3.30(1)-release
# requires:     md5sum (tested with version 8.23),
#               bc (tested with version 1.06.95),
#               s3cmd (tested with versions 1.5.0, 1.6.1 and 2.0.0),
#               parallel (tested with version 20130922),
#               swift -- Python client for the Swift API (tested with v2.3.1),
#               mc -- Minio Client for the S3 API as replacement for s3cmd 
#                     (tested with v2017-06-15T03:38:43Z)
#               az -- Python client for the Azure CLI (tested with v2.0),
#               gsutil -- Python client for the Google API (tested with v4.27)
# notes:        s3cmd need to be configured first via s3cmd --configure
#               gsutil need to be configured first via gsutil config -a
# example:      ./s3perf.sh -n 5 -s 1048576 # 5 files of 1 MB size each
# ----------------------------------------------------------------------------

# Check if the required command line tools are available
command -v s3cmd >/dev/null 2>&1 || { echo >&2 "s3perf requires the command line tool s3cmd. Please install it."; exit 1; }
command -v bc >/dev/null 2>&1 || { echo >&2 "s3perf requires the command line tool bc. Please install it."; exit 1; }
command -v md5sum >/dev/null 2>&1 || { echo >&2 "s3perf requires the command line tool md5sum. Please install it."; exit 1; }
command -v ping >/dev/null 2>&1 || { echo >&2 "s3perf requires the command line tool ping Please install it."; exit 1; }

function usage
{
echo "$SCRIPT -n files -s size [-b <bucket>] [-u] [-a] [-m <alias>] [-z] [-g] [-k] [-p] [-o]

This script analyzes the performance and data integrity of S3-compatible
storage services 

Arguments:
-h : show this message on screen
-n : number of files to be created
-s : size of the files to be created in bytes (max 16777216 = 16 MB)
-b : s3perf will create per default a new bucket s3perf-testbucket (or S3PERF-TESTBUCKET, in case the argument -u is set). This is not a problem when private cloud deployments are investigated, but for public cloud scenarios it may become a problem, because object-based stoage services implement a global bucket namespace. This means that all bucket names must be unique. With the argument -b <bucket> the users of s3perf have the freedom to specify the bucket name
-u : use upper-case letters for the bucket name (this is required for Nimbus Cumulus and S3ninja)
-a : use the Swift API and not the S3 API (this requires the python client for the Swift API and the environment variables ST_AUTH, ST_USER and ST_KEY)
-m : use the S3 API with the Minio Client (mc) instead of s3cmd. It is required to provide the alias of the mc configuration that shall be used
-z : use the Azure CLI instead of the S3 API (this requires the python client for the Azure CLI and the environment variables AZURE_STORAGE_ACCOUNT and AZURE_STORAGE_ACCESS_KEY)
-g : use the Google Cloud Storage CLI instead of the s3cmd (this requires the python client for the Google API)
-k : keep the local files and the directory afterwards (do not clean up)
-p : upload and download the files in parallel
-o : appended the results to a local file results.csv
"
exit 0
}

SCRIPT=${0##*/}   # script name
NUM_FILES=
SIZE_FILES=
BUCKETNAME_PARAMETER=0
UPPERCASE=0
SWIFT_API=0
MINIO_CLIENT=0
MINIO_CLIENT_ALIAS=
AZURE_CLI=0
GOOGLE_API=0
NOT_CLEAN_UP=0
PARALLEL=0
LIST_OF_FILES=
OUTPUT_FILE=0

RED='\033[0;31m'          # Red color
NC='\033[0m'              # No color
GREEN='\033[0;32m'        # Green color
YELLOW='\033[0;33m'       # Yellow color
BLUE='\033[0;34m'         # Blue color
WHITE='\033[0;37m'        # White color

while getopts "hn:s:b:uamzgkpo" Arg ; do
  case $Arg in
    h) usage ;;
    n) NUM_FILES=$OPTARG ;;
    s) SIZE_FILES=$OPTARG ;;
    # If the flag has been set => $NOT_CLEAN_UP gets value 1
    b) BUCKETNAME_PARAMETER=1
       BUCKET=$OPTARG ;; 
    u) UPPERCASE=1 ;;
    a) SWIFT_API=1 ;;
    m) MINIO_CLIENT=1 
       MINIO_CLIENT_ALIAS=$OPTARG ;;
    z) AZURE_CLI=1 ;;
    g) GOOGLE_API=1 ;;
    k) NOT_CLEAN_UP=1 ;;
    p) PARALLEL=1 ;;
    o) OUTPUT_FILE=1 ;;
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

if [ "$MINIO_CLIENT" -eq 1 ] ; then
  # ... the script needs to check, if the command line tool mc is installed
  command -v mc >/dev/null 2>&1 || { echo -e >&2 "If the Minio Minio Client (mc) shall be used instead of s3cmd, it need to be installed und configured first. Please install it.\nThe installation is well documented here: https://github.com/minio/mc \nThe configuration can be done via this command:\nmc config host add <ALIAS> http://<IP>:<PORT> <ACCESSKEY> <SECRETKEY> S3v4 "; exit 1; }
fi

# Only if the user wants to use the Swift API and not the S3 API
if [ "$SWIFT_API" -eq 1 ] ; then
  # ... the script needs to check, if the command line tool swift is installed
  command -v swift >/dev/null 2>&1 || { echo -e >&2 "If the Swift API shall be used, the command line tool swift need to be installed first. Please install it. Probably these commands will install the swift client:\ncd \$HOME; git clone https://github.com/openstack/python-swiftclient.git\ncd \$HOME/python-swiftclient; sudo python setup.py develop; cd -."; exit 1; }

  # ... the script needs to check, if the environment variable ST_AUTH is set
  if [ -z "$ST_AUTH" ] ; then
    echo -e "If the Swift API shall be used, the environment variable ST_AUTH must contain the Auth URL of the storage service. Please set it with this command:\nexport ST_AUTH=http://<IP_or_URL>/auth/v1.0" && exit 1
  fi
  
  # ... the script needs to check, if the environment variable ST_USER is set
  if [ -z "$ST_USER" ] ; then
    echo -e "If the Swift API shall be used, the environment variable ST_USER must contain the Username of the storage service. Please set it with this command:\nexport ST_USER=<username>" && exit 1
  fi
  
  # ... the script needs to check, if the environment variable ST_KEY is set
  if [ -z "$ST_KEY" ] ; then
    echo -e "If the Swift API shall be used, the environment variable ST_KEY must contain the Password of the storage service. Please set it with this command:\nexport ST_KEY=<password>" && exit 1
  fi
fi

# Only if the user wants to use the Azure CLI and not the S3 API
if [ "$AZURE_CLI" -eq 1 ] ; then
  # ... the script needs to check, if the command line tool az installed
  command -v az >/dev/null 2>&1 || { echo -e >&2 "If the Azure CLI shall be used, the command line tool az need to be installed first. Please install it. Probably these commands will install the az client:\ncd $HOME; curl -L https://aka.ms/InstallAzureCli | bash; exec -l $SHELL"; exit 1; }
  
  # ... the script needs to check, if the environment variable AZURE_STORAGE_ACCOUNT is set
  if [ -z "$AZURE_STORAGE_ACCOUNT" ] ; then
    echo -e "If the Azure CLI shall be used, the environment variable AZURE_STORAGE_ACCOUNT must contain the Storage Account Name of the storage service. Please set it with this command:\nexport AZURE_STORAGE_ACCOUNT=<storage_account_name>" && exit 1
  fi
  
  # ... the script needs to check, if the environment variable AZURE_STORAGE_ACCESS_KEY is set
  if [ -z "$AZURE_STORAGE_ACCESS_KEY" ] ; then
    echo -e "If the Azure CLI shall be used, the environment variable AZURE_STORAGE_ACCESS_KEY must contain the Account Key of the storage service. Please set it with this command:\nexport AZURE_STORAGE_ACCESS_KEY=<storage_account_key>" && exit 1
  fi
fi

# Only if the user wants to use the Google API and not the S3 API
if [ "$GOOGLE_API" -eq 1 ] ; then
  # ... the script needs to check, if the command line tool gsutil installed
  command -v gsutil >/dev/null 2>&1 || { echo -e >&2 "If the Google Cloud Storage CLI shall be used, the command line tool gsutil need to be installed first. Please install it. Probably these commands will install the gsutil client:\nsudo apt install python-pip; sudo pip install gsutil"; exit 1; }
fi

# Path of the directory for the files
DIRECTORY="testfiles"
# Name for the bucket to store the files
# ATTENTION! When using Google Cloud Storage, Amazon S3, Swift or FakeS3, it is ok when the bucket name is written in lower case.
# But when using Nimbus Cumulus and S3ninja, the bucket name needs to be in upper case.
# Minio, Riak CS, S3rver and Scality S3 do not accept bucket names with upper-case letters.
# 
# A helpful source about this topic is: http://docs.rightscale.com/faq/clouds/aws/What_are_valid_S3_bucket_names.html
# "In order to conform with DNS requirements, we recommend following these additional guidelines when creating buckets:"
# "Bucket names should not contain upper-case letters"
# "Bucket names should not contain underscores (_)"
# "Bucket names should not end with a dash"
# "Bucket names should be between 3 and 63 characters long"
# "Bucket names cannot contain dashes next to periods (e.g., my-.bucket.com and my.-bucket are invalid)"
# "Bucket names cannot contain periods"

# Filename of the output file
OUTPUT_FILENAME=results.csv

# If the user did not want to specify the bucket name with the parameter -b <bucket>, s3perf will use the default bucket name
if [ "$BUCKETNAME_PARAMETER" -eq 0 ] ; then
  if [ "$UPPERCASE" -eq 1 ] ; then
    # Default bucket name in case the parameter -u was set => $UPPERCASE has value 1
    BUCKET="S3PERF-TESTBUCKET"
  else
    # Default bucket name in case the parameter -u was not set => $UPPERCASE has value 0
    BUCKET="s3perf-testbucket"
  fi
fi

# Validate that...
# NUM_FILES is not 0 
if [ "$NUM_FILES" -eq 0 ] ; then
  echo -e "${RED}Attention: The number of files must not be value zero!${NC}"
  usage
  exit 1
fi

# Validate that...
# SIZE_FILES is not 0 and not bigger than 16777216
if ( [[ "$SIZE_FILES" -eq 0 ]] || [[ "$SIZE_FILES" -gt 16777216 ]] ) ; then
   echo -e "${RED}Attention: The size of the file(s) must not 0 and the maximum size is 16.777.216 Byte!${NC}"
   usage
   exit 1
fi
 
 

# Check if we have a working network connection by sending a ping to 8.8.8.8
if ping -q -c 1 -W 1 8.8.8.8 >/dev/null ; then
  echo -e "${GREEN}[OK] This computer has a working internet connection.${NC}"
else
  echo -e "${RED}[ERROR] This computer has no working internet connection. Please check your network settings.${NC}" && exit 1
fi

# Check if the directory already exists
# This is not a part of the benchmark!
if [ -e ${DIRECTORY} ] ; then
  # Terminate the script, in case the directory already exists
  echo -e "${RED}[ERROR] The directory ${DIRECTORY} already exists in the local directory!${NC}" && exit 1
else
  if mkdir ${DIRECTORY} ; then
    # Create the directory if it does not already exist
    echo -e "${GREEN}[OK] The directory ${DIRECTORY} has been created in the local directory.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the directory ${DIRECTORY} in the local directory.${NC}" && exit 1
  fi
fi

# Create files with random content of given size
# This is not a part of the benchmark!
for ((i=1; i<=${NUM_FILES}; i+=1))
do
  if dd if=/dev/urandom of=$DIRECTORY/s3perf-testfile$i.txt bs=1 count=$SIZE_FILES ; then
    echo -e "${GREEN}[OK] Files with random content have been created.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the files.${NC}" && exit 1
  fi
done

# Calculate the checksums of the files
# This is not a part of the benchmark!
if md5sum $DIRECTORY/* > $DIRECTORY/MD5SUM ; then
  echo -e "${GREEN}[OK] Checksums have been calculated and MD5SUM file has been created.${NC}"
else
  echo -e "${RED}[ERROR] Unable to calculate the checksums and create the MD5SUM file.${NC}" && exit 1
fi


# Start of the 1st time measurement
TIME_CREATE_BUCKET_START=`date +%s.%N`

# -------------------------------
# | Create a bucket / container |
# -------------------------------
# In the Swift and Azure ecosystem, the buckets are called conainers. 

# use the Swift API
if [ "$SWIFT_API" -eq 1 ] ; then
  if swift post $BUCKET ; then
    echo -e "${GREEN}[OK] Bucket ${BUCKET} has been created.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the bucket (container) ${BUCKET}.${NC}" && exit 1
  fi
elif [ "$MINIO_CLIENT" -eq 1 ] ; then
  # use the S3 API with mc
  if mc mb $MINIO_CLIENT_ALIAS/$BUCKET; then
    echo -e "${GREEN}[OK] Bucket ${BUCKET} has been created.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the bucket ${BUCKET}.${NC}" && exit 1
  fi
elif [ "$AZURE_CLI" -eq 1 ] ; then
  # use the Azure CLI
  if az storage container create --name $BUCKET ; then
    echo -e "${GREEN}[OK] Bucket ${BUCKET} has been created.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the bucket (container) ${BUCKET}.${NC}" && exit 1
  fi
elif [ "$GOOGLE_API" -eq 1 ] ; then
  # use the Google API
  if gsutil mb -l EU gs://$BUCKET ; then
    echo -e "${GREEN}[OK] Bucket ${BUCKET} has been created.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the bucket (container) ${BUCKET}.${NC}" && exit 1
  fi
else
  # use the S3 API with s3cmd
  if s3cmd mb s3://$BUCKET ; then
    echo -e "${GREEN}[OK] Bucket ${BUCKET} has been created.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to create the bucket ${BUCKET}.${NC}" && exit 1
  fi
fi

# End of the 1st time measurement
TIME_CREATE_BUCKET_END=`date +%s.%N`

# Duration of the 1st time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_CREATE_BUCKET=`echo "scale=3 ; (${TIME_CREATE_BUCKET_END} - ${TIME_CREATE_BUCKET_START})/1" | bc | sed 's/^\./0./'`

# Wait a moment. Sometimes, the services cannot provide fresh created buckets this quick
sleep 1

# Check that the bucket is really available. Strange things happened with some services in the past...

# !!! This is not part of any time measurements !!!

# use the S3 API with s3cmd
if [ "$SWIFT_API" -ne 1 ] ; then
  # We shall check at least 5 times
  LOOP_VARIABLE=5
  # until LOOP_VARIABLE is greater than 0 
  while [ $LOOP_VARIABLE -gt "0" ]; do 
    # Check if the Bucket is accessible
    if s3cmd ls s3://$BUCKET ; then
      echo -e "${GREEN}[OK] The bucket is available.${NC}"
      # Skip entire rest of loop.
      break
    else
      echo -e "${YELLOW}[INFO] The bucket is not yet available!${NC}"
      # Decrement variable
      LOOP_VARIABLE=$((LOOP_VARIABLE-1))
      # Wait a moment. 
      sleep 1
    fi
  done
fi

# Start of the 2nd time measurement
TIME_OBJECTS_UPLOAD_START=`date +%s.%N`


# ------------------------------
# | Upload the Files (Objects) |
# ------------------------------

# If the "parallel" flag has been set, upload in parallel with GNU parallel
if [ "$PARALLEL" -eq 1 ] ; then
  # use the Swift API
  if [ "$SWIFT_API" -eq 1 ] ; then
    # Upload files in parallel
    # The swift client can upload in parallel (and does so per default) but in order to keep the code simple,
    # s3perf uses the parallel command here too.
    if find $DIRECTORY/*.txt | parallel swift upload --object-threads 1 $BUCKET {} ; then
      echo -e "${GREEN}[OK] Files have been uploaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to upload the files.${NC}" && exit 1
    fi    
  elif [ "$MINIO_CLIENT" -eq 1 ] ; then
  # use the S3 API with mc
    # Upload files in parallel
    if find $DIRECTORY/*.txt | parallel mc cp {} $MINIO_CLIENT_ALIAS/$BUCKET  ; then
      echo -e "${GREEN}[OK] Files have been uploaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to upload the files.${NC}" && exit 1
    fi
  elif [ "$AZURE_CLI" -eq 1 ] ; then
  # use the Azure CLI
  # The Azure CLI upload in parallel per default and can't use GNU Parallel.
    # Upload files in parallel
    if find $DIRECTORY/*.txt | az storage blob upload-batch --destination $BUCKET --source $DIRECTORY/ ; then
      echo -e "${GREEN}[OK] Files have been uploaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to upload the files.${NC}" && exit 1
    fi
  elif [ "$GOOGLE_API" -eq 1 ] ; then
  # use the Google API
  # The Google API upload in parallel per -m and can't use GNU Parallel.
    # Upload files in parallel
    if find $DIRECTORY/*.txt | gsutil -m cp -r $DIRECTORY/*.txt gs://$BUCKET ; then
      echo -e "${GREEN}[OK] Files have been uploaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to upload the files.${NC}" && exit 1
    fi
  else
  # use the S3 API with s3cmd
    # Upload files in parallel
    if find $DIRECTORY/*.txt | parallel s3cmd put {} s3://$BUCKET ; then
      echo -e "${GREEN}[OK] Files have been uploaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to upload the files.${NC}" && exit 1
    fi
  fi
else
# If the "parallel" flag has NOT been set, upload the files sequentially
  # use the Swift API
  if [ "$SWIFT_API" -eq 1 ] ; then
    # Upload files sequentially
    # The swift client can upload in parallel (and does so per default) but in order to keep the code simple,
    # s3perf uses the parallel command here too.
    if swift upload --object-threads 1 $BUCKET $DIRECTORY/*.txt ; then
      echo -e "${GREEN}[OK] Files have been uploaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to upload the files.${NC}" && exit 1
    fi
  elif [ "$MINIO_CLIENT" -eq 1 ] ; then
  # use the S3 API with mc
    # Upload files sequentially
    if mc cp $DIRECTORY/*.txt $MINIO_CLIENT_ALIAS/$BUCKET ; then
      echo -e "${GREEN}[OK] Files have been uploaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to upload the files.${NC}" && exit 1
    fi
  elif [ "$AZURE_CLI" -eq 1 ] ; then
  # use the Azure CLI
    # Upload files sequentially
    if az storage blob upload-batch --destination $BUCKET --source $DIRECTORY/ ; then
      echo -e "${GREEN}[OK] Files have been uploaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to upload the files.${NC}" && exit 1
    fi
  elif [ "$GOOGLE_API" -eq 1 ] ; then
  # use the Google API
    # Upload files sequentially
    if gsutil cp -r $DIRECTORY/*.txt gs://$BUCKET ; then
      echo -e "${GREEN}[OK] Files have been uploaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to upload the files.${NC}" && exit 1
    fi
  else
  # use the S3 API with s3cmd
    # Upload files sequentially
    if s3cmd put $DIRECTORY/*.txt s3://$BUCKET ; then
      echo -e "${GREEN}[OK] Files have been uploaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to upload the files.${NC}" && exit 1
    fi
  fi
fi

# End of the 2nd time measurement
TIME_OBJECTS_UPLOAD_END=`date +%s.%N`


# Duration of the 2nd time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_OBJECTS_UPLOAD=`echo "scale=3 ; (${TIME_OBJECTS_UPLOAD_END} - ${TIME_OBJECTS_UPLOAD_START})/1" | bc | sed 's/^\./0./'`


# Calculate the bandwidth
# ((Size of the objects * number of objects * 8 bits per byte) / TIME_OBJECTS_UPLOAD) and next
# convert to Megabit per second
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
BANDWIDTH_OBJECTS_UPLOAD=`echo "scale=3 ; ((((${SIZE_FILES} * ${NUM_FILES} * 8) / ${TIME_OBJECTS_UPLOAD}) / 1000) / 1000) / 1" | bc | sed 's/^\./0./'`


# Wait a moment. Sometimes, the services cannot provide fresh uploaded files this quick
sleep 1

# Start of the 3rd time measurement
TIME_OBJECTS_LIST_START=`date +%s.%N`

# ----------------------------------------
# | List files inside bucket / container |
# ----------------------------------------
# In the Swift and Azure ecosystem, the buckets are called conainers. 

# use the Swift API
if [ "$SWIFT_API" -eq 1 ] ; then
  if swift list $BUCKET ; then
    echo -e "${GREEN}[OK] The list of objects inside ${BUCKET} has been fetched.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to fetch the list of objects inside ${BUCKET}.${NC}" && exit 1
  fi
elif [ "$MINIO_CLIENT" -eq 1 ] ; then
  # use the S3 API with mc
  if mc ls $MINIO_CLIENT_ALIAS/$BUCKET; then
    echo -e "${GREEN}[OK] The list of objects inside ${BUCKET} has been fetched.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to fetch the list of objects inside ${BUCKET}.${NC}" && exit 1
  fi
elif [ "$AZURE_CLI" -eq 1 ] ; then
  # use the Azure CLI
  if az storage blob list --container-name $BUCKET --output table ; then
    echo -e "${GREEN}[OK] The list of objects inside ${BUCKET} has been fetched.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to fetch the list of objects inside ${BUCKET}.${NC}" && exit 1
  fi
elif [ "$GOOGLE_API" -eq 1 ] ; then
  # use the Google API
  if gsutil ls gs://$BUCKET ; then
    echo -e "${GREEN}[OK] The list of objects inside ${BUCKET} has been fetched.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to fetch the list of objects inside ${BUCKET}.${NC}" && exit 1
  fi
else
  # use the S3 API with s3cmd
  if s3cmd ls s3://$BUCKET ; then
    echo -e "${GREEN}[OK] The list of objects inside ${BUCKET} has been fetched.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to fetch the list of objects inside ${BUCKET}.${NC}" && exit 1
  fi
fi

# End of the 3rd time measurement
TIME_OBJECTS_LIST_END=`date +%s.%N`

# Duration of the 3rd time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_OBJECTS_LIST=`echo "scale=3 ; (${TIME_OBJECTS_LIST_END} - ${TIME_OBJECTS_LIST_START})/1" | bc | sed 's/^\./0./'`


# Start of the 4th time measurement
TIME_OBJECTS_DOWNLOAD_START=`date +%s.%N`

# --------------------------------
# | Download the Files (Objects) |
# --------------------------------

# If the "parallel" flag has been set, download in parallel with GNU parallel
if [ "$PARALLEL" -eq 1 ] ; then
  # use the Swift API
  if [ "$SWIFT_API" -eq 1 ] ; then
    # Download files in parallel 
    # The swift client can download in parallel (and does so per default) but in order to keep the code simple,
    # s3perf uses the parallel command here too.
    if find $DIRECTORY/*.txt | parallel swift download --object-threads=1 $BUCKET {} ; then
      echo -e "${GREEN}[OK] Files have been downloaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to downloaded. the files.${NC}" && exit 1
    fi
  elif [ "$MINIO_CLIENT" -eq 1 ] ; then
  # use the S3 API with mc
    # Download files in parallel
    if find $DIRECTORY/*.txt | parallel mc cp $MINIO_CLIENT_ALIAS/$BUCKET/{} $DIRECTORY  ; then
      echo -e "${GREEN}[OK] Files have been downloaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to upload the files.${NC}" && exit 1
    fi
  elif [ "$AZURE_CLI" -eq 1 ] ; then
  # use the Azure CLI
    # Download files in parallel
    # The Azure CLI download in parallel per default and can't use GNU Parallel.
    if find $DIRECTORY/*.txt | az storage blob download-batch --destination $DIRECTORY/ --source $BUCKET ; then
      echo -e "${GREEN}[OK] Files have been downloaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to downloaded. the files." && exit 1
    fi
  elif [ "$GOOGLE_API" -eq 1 ] ; then
  # use the Google API
    # Download files in parallel
    # The Google API download in parallel per -m and can't use GNU Parallel.
    if find $DIRECTORY/*.txt | gsutil -m cp -r gs://$BUCKET $DIRECTORY/ ; then
      echo -e "${GREEN}[OK] Files have been downloaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to downloaded. the files.${NC}" && exit 1
    fi
  else
  # use the S3 API with s3cmd
    # Download files in parallel
    if find ${DIRECTORY}/*.txt -type f -printf "%f\n" | parallel s3cmd get --force s3://$BUCKET/{} $DIRECTORY/ ; then
      echo -e "${GREEN}[OK] Files have been downloaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to download the files.${NC}" && exit 1
    fi
  fi
else
  # use the Swift API
  if [ "$SWIFT_API" -eq 1 ] ; then
    # Download files sequentially
    if swift download --object-threads=1 $BUCKET $DIRECTORY/*.txt ; then
      echo -e "${GREEN}[OK] Files have been downloaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to download the files.${NC}" && exit 1
    fi
  elif [ "$MINIO_CLIENT" -eq 1 ] ; then
  # use the S3 API with mc
    # Download files sequentially
    if mc cp -r $MINIO_CLIENT_ALIAS/$BUCKET $DIRECTORY ; then
      # mc has up to now not the feature to copy the files directly into the desired folder.
      # All we can do here is to copy the entire bucket in to the folder as a subfolder and 
      # later move the files from the subfolder to the desired destination and afterwards 
      # remove the subfolder.
      mv $DIRECTORY/$BUCKET/*.txt $DIRECTORY
      rmdir $DIRECTORY/$BUCKET
      echo -e "${GREEN}[OK] Files have been downloaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to download the files.${NC}" && exit 1
    fi
  elif [ "$AZURE_CLI" -eq 1 ] ; then
  # use the Azure CLI
    # Download files sequentially
    if az storage blob download-batch --destination $DIRECTORY/ --source $BUCKET ; then
      echo -e "${GREEN}[OK] Files have been downloaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to download the files.${NC}" && exit 1
    fi
  elif [ "$GOOGLE_API" -eq 1 ] ; then
  # use the Google API
    # Download files sequentially
    if gsutil cp -r gs://$BUCKET/*.txt $DIRECTORY/ ; then
      echo -e "${GREEN}[OK] Files have been downloaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to downloaded. the files.${NC}" && exit 1
    fi
  else
  # use the S3 API with s3cmd
    # Download files sequentially
    if s3cmd get --force s3://$BUCKET/*.txt $DIRECTORY/ ; then
      echo -e "${GREEN}[OK] Files have been downloaded.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to download the files.${NC}" && exit 1
    fi
  fi
fi

# End of the 4th time measurement
TIME_OBJECTS_DOWNLOAD_END=`date +%s.%N`

# Duration of the 4th time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_OBJECTS_DOWNLOAD=`echo "scale=3 ; (${TIME_OBJECTS_DOWNLOAD_END} - ${TIME_OBJECTS_DOWNLOAD_START})/1" | bc | sed 's/^\./0./'`


# Validate the checksums of the files
# This is not a part of the benchmark!
if md5sum -c $DIRECTORY/MD5SUM ; then
  echo -e "${GREEN}[OK] Checksums have been validated and match the files.${NC}"
else
  echo -e "${RED}[ERROR] The checksums do not match the files.${NC}" && exit 1
fi


# Calculate the bandwidth
# ((Size of the objects * number of objects * 8 bits per byte) / TIME_OBJECTS_DOWNLOAD) and next
# convert to Megabit per second
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
BANDWIDTH_OBJECTS_DOWNLOAD=`echo "scale=3 ; ((((${SIZE_FILES} * ${NUM_FILES} * 8) / ${TIME_OBJECTS_DOWNLOAD}) / 1000) / 1000) / 1" | bc | sed 's/^\./0./'`


# Start of the 5th time measurement
TIME_ERASE_OBJECTS_START=`date +%s.%N`

# -----------------------------
# | Erase the Files (Objects) |
# -----------------------------

# If the "parallel" flag has been set, download in parallel with GNU parallel
if [ "$PARALLEL" -eq 1 ] ; then
  # use the Swift API
  if [ "$SWIFT_API" -eq 1 ] ; then
    # Erase files (objects) inside the bucket in parallel 
    # The swift client can erase in parallel (and does so per default) but in order to keep the code simple,
    # s3perf uses the parallel command here too.
    if find $DIRECTORY/*.txt | parallel swift delete --object-threads=1 $BUCKET {} ; then
      echo -e "${GREEN}[OK] Files inside the bucket (container) ${BUCKET} have been erased.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to erase the files inside the bucket (container) ${BUCKET}.${NC}" && exit 1
    fi
  elif [ "$MINIO_CLIENT" -eq 1 ] ; then
  # use the S3 API with mc
    # Erase files (objects) inside the bucket and the bucket itself sequentially!!!
    # Up to now it is impossible to erase just the files inside a bucket
    if mc rm -r --force $MINIO_CLIENT_ALIAS/$BUCKET  ; then
      echo -e "${GREEN}[OK] Files inside the bucket ${BUCKET} have been erased.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to erase the files inside the bucket ${BUCKET}.${NC}" && exit 1
    fi
  elif [ "$AZURE_CLI" -eq 1 ] ; then
  # use the Azure CLI
    # Erase files (objects) inside the bucket in parallel
    # The Azure CLI delete in parallel per default and can't use GNU Parallel.
    for i in `az storage blob list --container-name $BUCKET --output table | awk '{print $1}'| sed '1,2d' | sed '/^$/d'` ; do
      if az storage blob delete --name $i --container-name $BUCKET >/dev/null ; then
        echo -e "${GREEN}[OK] File $i inside the $BUCKET have been erased.${NC}"
      else
        echo -e "${RED}[ERROR] Unable to erase the file $i inside the  $BUCKET.${NC}" && exit 1
      fi
    done
  elif [ "$GOOGLE_API" -eq 1 ] ; then
  # use the Google API
    # The Google API delete in parallel per -m and can't use GNU Parallel.
    if find $DIRECTORY/*.txt | gsutil -m rm gs://$BUCKET/* ; then
      echo -e "${GREEN}[OK] Files inside the bucket (container) ${BUCKET} have been erased.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to erase the files inside the bucket (container) ${BUCKET}.${NC}" && exit 1
    fi
  else
  # use the S3 API with s3cmd
    #  Erase files (objects) inside the bucket in parallel
    if find $DIRECTORY/*.txt | parallel s3cmd del --recursive s3://$BUCKET/* ; then
      echo -e "${GREEN}[OK] Files inside the bucket ${BUCKET} have been erased.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to erase the files inside the bucket ${BUCKET}.${NC}" && exit 1
    fi
  fi
else
  # use the Swift API
  if [ "$SWIFT_API" -eq 1 ] ; then
    # Erase files (objects) inside the bucket sequentially
    if swift delete --object-threads=1 $BUCKET $DIRECTORY/*.txt ; then
      echo -e "${GREEN}[OK] Files inside the bucket (container) ${BUCKET} have been erased.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to erase the files inside the bucket (container) ${BUCKET}.${NC}" && exit 1
    fi
  elif [ "$MINIO_CLIENT" -eq 1 ] ; then
  # use the S3 API with mc
    # Erase files (objects) inside the bucket and the bucket itself sequentially
    # Up to now it is impossible to erase just the files inside a bucket
    if mc rm -r --force $MINIO_CLIENT_ALIAS/$BUCKET  ; then
      echo -e "${GREEN}[OK] Files inside the bucket ${BUCKET} and the bucket itself have been erased.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to erase the files inside the bucket ${BUCKET}.${NC}" && exit 1
    fi
  elif [ "$AZURE_CLI" -eq 1 ] ; then
  # use the Azure CLI
    # Erase files (objects) inside the bucket sequentially
    for i in `az storage blob list --container-name $BUCKET --output table | awk '{print $1}'| sed '1,2d' | sed '/^$/d'` ; do
      if az storage blob delete --name $i --container-name $BUCKET >/dev/null ; then
        echo -e "${GREEN}[OK] File $i inside the $BUCKET have been erased.${NC}"
      else
        echo -e "${RED}[ERROR] Unable to erase the file $i inside the $BUCKET.${NC}" && exit 1
      fi
    done
  elif [ "$GOOGLE_API" -eq 1 ] ; then
  # use the Google API
    # Erase files (objects) inside the bucket sequentially
    if gsutil rm gs://$BUCKET/* ; then
      echo -e "${GREEN}[OK] Files inside the bucket (container) ${BUCKET} have been erased.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to erase the files inside the bucket (container) ${BUCKET}.${NC}" && exit 1
    fi
  else
  # use the S3 API with s3cmd
    # Erase files (objects) inside the bucket sequentially
    if s3cmd del s3://$BUCKET/* ; then
      echo -e "${GREEN}[OK] Files inside the bucket ${BUCKET} have been erased.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to erase the files inside the bucket ${BUCKET}.${NC}" && exit 1
    fi
  fi
fi  

# End of the 5th time measurement
TIME_ERASE_OBJECTS_END=`date +%s.%N`


# Duration of the 5th time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_ERASE_OBJECTS=`echo "scale=3 ; (${TIME_ERASE_OBJECTS_END} - ${TIME_ERASE_OBJECTS_START})/1" | bc | sed 's/^\./0./'`


# Create the bucket again in case mc is used, because it is impossible to erase just the objects.
# We need a bucket to erase it in the next step.

# Check that the bucket is really gone and then create it new. 
# Strange things happened with some services in the past...

# !!! This is not part of any time measurements !!!

# use the S3 API with mc
if [ "$MINIO_CLIENT" -eq 1 ] ; then
  # We shall check at least 5 times
  LOOP_VARIABLE=5
  echo -e "${GREEN}[OK] Check again that the ${BUCKET} is gone.${NC}"
  # until LOOP_VARIABLE is greater than 0 
  while [ $LOOP_VARIABLE -gt "0" ]; do 
    # Check if the Bucket is accessible
    if mc ls $MINIO_CLIENT_ALIAS/$BUCKET > /dev/null 2>&1 ; then
      echo -e "${YELLOW}[INFO] The bucket ${BUCKET} is still available, which is not the desired result.${NC}"
      # Wait a moment. 
      sleep 1
      # Decrement variable
      LOOP_VARIABLE=$((LOOP_VARIABLE-1))
    else
      echo -e "${GREEN}[OK] The bucket ${BUCKET} has been gone!${NC}"
      # Skip entire rest of loop.
      break    
    fi
  done
  
  # Create the bucket again in order to erase it inthe next step
  if mc mb $MINIO_CLIENT_ALIAS/$BUCKET; then
    echo -e "${GREEN}[OK] Bucket ${BUCKET} has been created again to erase it as next step.${NC}"
    # Wait a moment. Sometimes, the services cannot provide fresh created buckets this quick
    sleep 1
  else
    echo -e "${RED}[ERROR] Unable to create the bucket ${BUCKET} again.${NC}" && exit 1
  fi
fi


# Start of the 6th time measurement
TIME_ERASE_BUCKET_START=`date +%s.%N`

# ----------------------------
# | Erase bucket / container |
# ----------------------------
# In the Swift and Azure ecosystem, the buckets are called conainers. 

# use the Swift API
if [ "$SWIFT_API" -eq 1 ] ; then
  if swift delete $BUCKET ; then
    echo -e "${GREEN}[OK] Bucket (Container) ${BUCKET} has been erased.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to erase the bucket (container) ${BUCKET}.${NC}" && exit 1
  fi
elif [ "$MINIO_CLIENT" -eq 1 ] ; then
  # use the S3 API with mc
  if mc rm $MINIO_CLIENT_ALIAS/$BUCKET; then
    echo -e "${GREEN}[OK] Bucket ${BUCKET} has been erased.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to erase the bucket ${BUCKET}.${NC}" && exit 1
  fi
elif [ "$AZURE_CLI" -eq 1 ] ; then
  # use the Azure CLI
  if az storage container delete --name $BUCKET ; then
    echo -e "${GREEN}[OK] Bucket (Container) ${BUCKET} has been erased.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to erase the bucket (container) ${BUCKET}.${NC}" && exit 1
  fi
elif [ "$GOOGLE_API" -eq 1 ] ; then
  # use the Google API
  if gsutil rm -r gs://$BUCKET ; then
   echo -e "${GREEN}[OK] Bucket (Container) ${BUCKET} has been erased.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to erase the bucket (container) ${BUCKET}.${NC}" && exit 1
  fi
else
  # use the S3 API with s3cmd
  if s3cmd rb --force --recursive s3://$BUCKET ; then
    echo -e "${GREEN}[OK] Bucket ${BUCKET} has been erased.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to erase the bucket ${BUCKET}.${NC}" && exit 1
  fi
fi

# End of the 6th time measurement
TIME_ERASE_BUCKET_END=`date +%s.%N`

# Duration of the 6th time measurement
# The "/1" is stupid, but it is required to get the "scale" working.
# Otherwise the "scale" is just ignored
# The sed command ensures that results < 1 have a leading 0 before the "."
TIME_ERASE_BUCKET=`echo "scale=3 ; (${TIME_ERASE_BUCKET_END} - ${TIME_ERASE_BUCKET_START})/1" | bc | sed 's/^\./0./'`

# If the "not clean up" flag has not been set, erase the local directory with the files
if [ "$NOT_CLEAN_UP" -ne 1 ] ; then
  # Erase the local directory with the files
  if rm -rf $DIRECTORY ; then
    echo -e "${GREEN}[OK] The directory ${DIRECTORY} has been erased.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to erase the directory ${DIRECTORY}.${NC}" && exit 1
  fi
fi

echo 'Required time to create the bucket:                 '${TIME_CREATE_BUCKET} s
echo 'Required time to upload the files:                  '${TIME_OBJECTS_UPLOAD} s
echo 'Required time to fetch a list of files:             '${TIME_OBJECTS_LIST} s
echo 'Required time to download the files:                '${TIME_OBJECTS_DOWNLOAD} s
echo 'Required time to erase the objects:                 '${TIME_ERASE_OBJECTS} s
echo 'Required time to erase the bucket:                  '${TIME_ERASE_BUCKET} s

TIME_SUM=`echo "scale=3 ; (${TIME_CREATE_BUCKET} + ${TIME_OBJECTS_UPLOAD} + ${TIME_OBJECTS_LIST} + ${TIME_OBJECTS_DOWNLOAD} + ${TIME_ERASE_OBJECTS} + ${TIME_ERASE_BUCKET})/1" | bc | sed 's/^\./0./'`

echo 'Required time to perform all S3-related operations: '${TIME_SUM} s
echo ''
echo 'Bandwidth during the upload of the files:           '${BANDWIDTH_OBJECTS_UPLOAD} Mbps
echo 'Bandwidth during the download of the files:         '${BANDWIDTH_OBJECTS_DOWNLOAD} Mbps

# Create an output file only of the command line parameter was set => value of OUTPUT_FILE is not equal 0
if ([[ "$OUTPUT_FILE" -ne 0 ]]) ; then
  # If the output file did not already exist...
  if [ ! -f ${OUTPUT_FILENAME} ] ; then  
    # .. create in the first line the header first
    if echo -e "DATE TIME NUM_FILES SIZE_FILES TIME_CREATE_BUCKET TIME_OBJECTS_UPLOAD TIME_OBJECTS_LIST TIME_OBJECTS_DOWNLOAD TIME_ERASE_OBJECTS TIME_ERASE_BUCKET TIME_SUM BANDWIDTH_OBJECTS_UPLOAD BANDWIDTH_OBJECTS_DOWNLOAD" >> ${OUTPUT_FILENAME} ; then
      echo -e "${GREEN}[OK] A new output file ${OUTPUT_FILENAME} has been created.${NC}"
    else
      echo -e "${RED}[ERROR] Unable to create a new output file ${OUTPUT_FILENAME}.${NC}" && exit 1
    fi
  fi
  # If the output file did already exist...
  if echo -e "`date +%Y-%m-%d` `date +%H:%M:%S` ${NUM_FILES} ${SIZE_FILES} ${TIME_CREATE_BUCKET} ${TIME_OBJECTS_UPLOAD} ${TIME_OBJECTS_LIST} ${TIME_OBJECTS_DOWNLOAD} ${TIME_ERASE_OBJECTS} ${TIME_ERASE_BUCKET} ${TIME_SUM} ${BANDWIDTH_OBJECTS_UPLOAD} ${BANDWIDTH_OBJECTS_DOWNLOAD}" >> ${OUTPUT_FILENAME} ; then
    echo -e "${GREEN}[OK] The results of this benchmark run have been appended to the output file ${OUTPUT_FILENAME}.${NC}"
  else
    echo -e "${RED}[ERROR] Unable to append the results of this benchmark run to the output file ${OUTPUT_FILENAME}.${NC}" && exit 1
  fi
fi
