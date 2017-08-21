#!/bin/bash
#
# title:        benchmark_start.sh
# description:  This script can be used to start multiple benchmark runs of s3perf
#               for a detailed analysis of the performance of a storage service
# author:       Dr. Christian Baun
# url:          https://github.com/christianbaun/s3perf
# license:      GPLv2
# date:         August 21st 2017
# version:      1.03
# bash_version: 4.3.30(1)-release
# requires:     
# notes: 
# ----------------------------------------------------------------------------


for i in 512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304 8388608
# for i in 1048576 
  do
    for x in 1 2 3 4 5
#     for x in 1
      do
#         ./s3perf.sh -n 10 -s ${i} -p -o 2>&1 # Minio, RiakCS, FakeS3, S3rver und Scality parallel
#         ./s3perf.sh -n 10 -s ${i} -o 2>&1 # Minio, RiakCS, FakeS3, S3rver und Scality serial       
        ./s3perf.sh -n 10 -s ${i} -m minio -o 2>&1 # Minio with Minio Client (mc) serial      
#          ./s3perf.sh -n 10 -s ${i} -u -p -o 2>&1 # Nimbus Cumulus und S3ninja parallel
#          ./s3perf.sh -n 10 -s ${i} -u -o 2>&1 # Nimbus Cumulus und S3ninja serial
        # "$?" contains the return code of the last command executed.
        if [ "$?" -ne "0" ] ; then
          exit 1
        fi
        sleep 10
      done
  done

