#!/bin/bash
#
# title:        check_third_party_tools.sh
# description:  This script check the availabilty of the third party applications used by ossperf
# author:       Dr. Christian Baun
# contributors: 
# url:          https://github.com/christianbaun/ossperf
# license:      GPLv3
# date:         September 20th 2024
# version:      1.1
# bash_version: 5.2.21(1)-release
# requires:     md5sum (tested with version 8.26),
#               bc (tested with version 1.06.95),
#               s3cmd (tested with versions 1.5.0, 1.6.1 and 2.0.2),
#               parallel (tested with version 20161222)
# optional      swift -- Python client for the Swift API (tested with v2.3.1 and 4.1.0),
#               mc -- Minio Client for the S3 API (tested with RELEASE.2020-02-05T20-07-22Z)
#               az -- Python client for the Azure CLI (tested with v2.0),
#               gsutil -- Python client for the Google API (tested with v4.27 and 4.38)
#               aws -- AWS CLI client for the S3 API (tested with v1.15.6)
# notes:        s3cmd need to be configured first via s3cmd --configure
#               gsutil need to be configured first via gsutil config -a
# example:      ./check_third_party_tools.sh
# ----------------------------------------------------------------------------

RED='\033[0;31m'          # Red color
NC='\033[0m'              # No color
GREEN='\033[0;32m'        # Green color
YELLOW='\033[0;33m'       # Yellow color
BLUE='\033[0;34m'         # Blue color
WHITE='\033[0;37m'        # White color


# Check the operating system
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    # Linux
    echo -e "${YELLOW}[INFO] The operating system is Linux.${NC}"
    echo "${OSTYPE}"
elif [[ "$OSTYPE" == "freebsd"* ]]; then
    # FreeBSD
    echo -e "${YELLOW}[INFO] The operating system is FreeBSD.${NC}"
    echo "${OSTYPE}"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OS X
    echo -e "${YELLOW}[INFO] The operating system is Mac OS X.${NC}"
    echo "${OSTYPE}"
elif [[ "$OSTYPE" == "msys" ]]; then
    # Windows 
    echo -e "${YELLOW}[INFO] The operating system is Windows.${NC}"
    echo "${OSTYPE}"
elif [[ "$OSTYPE" == "cygwin" ]]; then
    # POSIX compatibility layer for Windows
    echo -e "${YELLOW}[INFO] POSIX compatibility layer for Windows detected.${NC}"
    echo "${OSTYPE}"
else
    # Unknown
    echo -e "${YELLOW}[INFO] The operating system is unknown.${NC}"
    echo "${OSTYPE}"
fi


# Check if the required command line tools are available
if ! [ -x "$(command -v bash)" ]; then
    echo -e "${RED}[ERROR] ossperf requires the bash command line interpreter. Please install it.${NC}"
else
    echo -e "${GREEN}[OK] The bash command line interpreter has been found on this system.${NC}"
    bash --version | head -n 1
fi

if ! [ -x "$(command -v s3cmd)" ]; then
    echo -e "${RED}[ERROR] ossperf requires the command line tool s3cmd. Please install it.${NC}"
else
    echo -e "${GREEN}[OK] The tool s3cmd has been found on this system.${NC}"
    s3cmd --version
fi

if ! [ -x "$(command -v bc)" ]; then
    echo -e "${RED}[ERROR] ossperf requires the command line tool bc. Please install it.${NC}"
else
    echo -e "${GREEN}[OK] The tool bc has been found on this system.${NC}"
    bc --version | head -n 1
fi

if ! [ -x "$(command -v md5sum)" ]; then
    echo -e "${RED}[ERROR] ossperf requires the command line tool md5sum. Please install it.${NC}"
else
    echo -e "${GREEN}[OK] The tool md5sum has been found on this system.${NC}"
    md5sum --version | head -n 1
fi

if ! [ -x "$(command -v ping)" ]; then
    echo -e "${RED}[ERROR] ossperf requires the command line tool ping. Please install it.${NC}"
else
    echo -e "${GREEN}[OK] The tool ping has been found on this system.${NC}"
    ping -V
fi

if ! [ -x "$(command -v parallel)" ]; then
    echo -e "${YELLOW}[INFO] The command line tool parallel was not found.${NC}"
else
    echo -e "${GREEN}[OK] The tool GNU parallel has been found on this system.${NC}"
    parallel --version | head -n 1
fi

if ! [ -x "$(command -v mc)" ]; then
    echo -e "${YELLOW}[INFO] The command line tool mc (MinIO) was not found.${NC}"
else
    echo -e "${GREEN}[OK] The Minio Client (mc) has been found on this system.${NC}"
    mc --version
fi

if ! [ -x "$(command -v s4cmd)" ]; then
    echo -e "${YELLOW}[INFO] The command line tool s4cmd was not found.${NC}"
else
    echo -e "${GREEN}[OK] The s4cmd client has been found on this system.${NC}"
    s4cmd --version
fi

if ! [ -x "$(command -v aws)" ]; then
    echo -e "${YELLOW}[INFO] The command line tool aws was not found.${NC}"
else
    echo -e "${GREEN}[OK] The AWS CLI Client (aws) has been found on this system.${NC}"
    aws --version 
fi

if ! [ -x "$(command -v swift)" ]; then
    echo -e "${YELLOW}[INFO] The command line tool swift was not found.${NC}"
else
    echo -e "${GREEN}[OK] The swift client has been found on this system.${NC}"
    swift --version
fi

if ! [ -x "$(command -v az)" ]; then
    echo -e "${YELLOW}[INFO] The command line tool azure-cli was not found.${NC}"
else
    echo -e "${GREEN}[OK] The tool az has been found on this system.${NC}"
    az --version | grep azure-cli
fi
