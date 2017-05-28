#!/bin/bash
#
# title:        benchmark_start.sh
# description:  This script starts the benchmark runs of s3perf
# author:       Dr. Christian Baun
# url:          https://github.com/christianbaun/s3perf
# license:      GPLv2
# date:         May 28th 2017
# version:      1
# bash_version: 4.3.30(1)-release
# requires:     
# notes: 
# ----------------------------------------------------------------------------


for i in 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192
  do
    ./s3perf.sh -n 10 -s ${i} -a -p -o 2>&1
    sleep 10
  done

