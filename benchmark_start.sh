#!/bin/bash
#
# title:        benchmark_start.sh
# description:  This script can be used to start multiple benchmark runs of ossperf
#               for a detailed analysis of the performance of a storage service
# author:       Dr. Christian Baun
# url:          https://github.com/christianbaun/ossperf
# license:      GPLv2
# date:         June 11th 2020
# version:      1.08
# bash_version: 4.4.12(1)-release
# requires:     
# notes: 
# ----------------------------------------------------------------------------

#for i in 4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304 8388608
for i in 8388608 
  do
    for x in 1 2 3 4 5
#     for x in 1
      do       
#          ./ossperf.sh -n 10 -s ${i} -m myminioneu -o 2>&1 # Minio Client (mc) serial   
#          ./ossperf.sh -n 10 -s ${i} -m myminioneu -p -o 2>&1 # Minio Client (mc) parallel       
#          ./ossperf.sh -n 10 -s ${i} -b ossperf-testbucket -o 2>&1 # s3cmd serial  
           ./ossperf.sh -n 10 -s ${i} -b ossperf-testbucket -p -o 2>&1 # s3cmd parallel     
#          ./ossperf.sh -n 10 -s ${i} -b ossperf-testbucket -l eu -o 2>&1 # s3cmd serial  
#          ./ossperf.sh -n 10 -s ${i} -b ossperf-testbucket -l eu -p -o 2>&1 # s3cmd parallel
#          ./ossperf.sh -n 10 -s ${i} -b ossperf-testbucket -g -o 2>&1 # gsutil serial
#           ./ossperf.sh -n 10 -s ${i} -b ossperf-testbucket -g -p -o 2>&1 # gsutil parallel
#          ./ossperf.sh -n 10 -s ${i} -b ossperf-testbucket -g -l europe-west3 -o 2>&1 # gsutil serial
           # Something like us, eu,  europe-west3, ...
#          ./ossperf.sh -n 10 -s ${i} -b ossperf-testbucket -g -l eu -p -o 2>&1 # gsutil parallel
#          ./ossperf.sh -n 10 -s ${i} -u -p -o 2>&1 # Nimbus Cumulus und S3ninja parallel
#          ./ossperf.sh -n 10 -s ${i} -u -o 2>&1 # Nimbus Cumulus und S3ninja serial
        # "$?" contains the return code of the last command executed.
        if [ "$?" -ne "0" ] ; then
           exit 1
        fi
        sleep 10
      done
  done
