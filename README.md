[![GPLv3 license](https://img.shields.io/badge/License-GPLv3-blue.svg)](http://perso.crans.org/besson/LICENSE.html)
[![made-with-bash](https://img.shields.io/badge/-Made%20with%20Bash-1f425f.svg)](https://www.gnu.org/software/bash/)

# OSSperf

OSSperf is a lightweight command-line tool for analyzing the performance and data integrity of storage services that implement the S3 API, the Swift API, or the Azure Blob Storage API. The tool creates a user-defined number of files with random content and of a specified size inside a local directory. The tool creates a bucket, uploads and downloads the files, and afterward removes the bucket. The time required to carry out theses S3/Swift/Azure-related tasks is measured and printed out on the command line.

Until November 2017, the OSSperf tool had the name S3perf because, initially, the tool had only implemented support for storage services, which implement the S3 API. Because now, the solution targets also storage services that implement different APIs, the tool was renamed to OSSperf. OSS stands for Object-based Storage Services.

Storage services tested with this tool are so far:
- [Amazon Simple Storage Service (S3)](https://aws.amazon.com/s3/)
- [Google Cloud Storage (GCS)](https://cloud.google.com/storage/)
- [Azure Blob Storage (ABS)](https://azure.microsoft.com/de-de/services/storage/blobs/)
- [Nimbus Cumulus](https://github.com/nimbusproject/nimbus)
- [Minio](https://github.com/minio/minio)
- [S3ninja](https://github.com/scireum/s3ninja/)
- [S3rver](https://github.com/jamhall/s3rver/)
- [Fake S3](https://github.com/jubos/fake-s3)
- [Scality S3](https://github.com/scality/S3)
- [Riak CS](https://github.com/basho/riak_cs)
- [OpenStack Swift](https://github.com/openstack/swift)

## Publications

- [**OSSperf - a lightweight solution for the performance evaluation of object-based cloud storage services**](https://journalofcloudcomputing.springeropen.com/articles/10.1186/s13677-017-0096-x). *Christian Baun, Henry-Norbert Cocos and Rosa-Maria Spanou*. Journal of Cloud Computing - Advances, Systems and Applications 2017 6:24 ([PDF](https://journalofcloudcomputing.springeropen.com/track/pdf/10.1186/s13677-017-0096-x))

## Synopsis

    ossperf.sh -n files -s size [-b <bucket>] [-u] [-a] [-m <alias>] [-z] [-g] [-w] [-l <location>] [-d <url>] [-k] [-p] [-o]

    This script analyzes the performance and data integrity of S3-compatible
    storage services 

    Arguments:
    -h : show this message on screen
    -n : number of files to be created
    -s : size of the files to be created in bytes (max 16777216 = 16 MB)
    -b : ossperf will create per default a new bucket ossperf-testbucket (or OSSPERF-TESTBUCKET, in case the argument -u is set). This is not a problem when private cloud deployments are investigated, but for public cloud scenarios it may become a problem, because object-based storage services implement a global bucket namespace. This means that all bucket names must be unique. With the argument -b <bucket> the users of ossperf have the freedom to specify the bucket name
    -u : use upper-case letters for the bucket name (this is required for Nimbus Cumulus and S3ninja)
    -a : use the Swift API and not the S3 API (this requires the python client for the Swift API and the environment variables ST_AUTH, ST_USER and ST_KEY)
    -m : use the S3 API with the Minio Client (mc) instead of s3cmd. It is required to provide the alias of the mc configuration that shall be used
    -z : use the Azure CLI instead of the S3 API (this requires the python client for the Azure CLI and the environment variables AZURE_STORAGE_ACCOUNT and AZURE_STORAGE_ACCESS_KEY)
    -g : use the Google Cloud Storage CLI instead of the s3cmd (this requires the python client for the Google API)
    -w : use the AWS CLI instead of the s3cmd (this requires the installation and configuration of the aws cli client)
    -l : use a specific site (location) for the bucket. This is supported e.g. by the AWS S3 and Google Cloud Storage
    -d : If the aws cli shall be used with an S3-compatible non-Amazon service, please specify with this parameter the endpoint-url
    -k : keep the local files and the directory afterwards (do not clean up)
    -p : upload and download the files in parallel
    -o : appended the results to a local file results.csv

## Requirements

These software packages must be installed:

- [bash](https://www.gnu.org/software/bash/) 4.3.30
- [bc](https://www.gnu.org/software/bc/) 1.06.95
- [md5sum](https://www.gnu.org/software/coreutils/) 8.26
- [parallel](https://www.gnu.org/software/parallel/) 20161222
- [s3cmd](https://github.com/s3tools/s3cmd) -- Command line tool for working with storage service that implement the S3 API (tested with version 1.5.0, 1.6.1 and 2.0.2)

These software packages are optional:

- [swift](https://github.com/openstack/python-swiftclient) -- Python client for the Swift API (tested with version 2.3.1)
- [mc](https://github.com/minio/mc) -- Minio Client for the S3 API (tested with version RELEASE.2020-02-05T20-07-22Z)
- [az](https://github.com/Azure/azure-cli) -- Python client for the Azure CLI (tested with version 2.0)
- [gsutil](https://github.com/GoogleCloudPlatform/gsutil) -- Python client for the Google Cloud Storage as replacement for s3cmd (tested with version 4.27 and 4.38)
- [aws](https://github.com/aws/aws-cli) -- AWS CLI client for the S3 API (tested with version 1.15.6)

## Examples

This command creates five files of size 1 MB each and uses them to test the performance and data integrity of the storage service. The new bucket used has the name ossperf-testbucket, and the uploads and downloads are carried out in parallel. The [s3cmd](https://github.com/s3tools/s3cmd) command line tool is used.

`./ossperf.sh -n 5 -s 1048576 -b ossperf-testbucket -p`

This command does the same, but uses the Minio Client [mc](https://github.com/minio/mc) for the S3 API insted of s3cmd.

`./ossperf.sh -n 5 -s 1048576 -b ossperf-testbucket -p -m minio`

This command creates ten files of size 512 kB each and uses them to test the performance and data integrity of the AWS S3 in the region eu-west-2 (Frankfurt am Main). The new bucket used has the name my-unique-bucketname, and the uploads and downloads are carried out in parallel. The [aws](https://github.com/aws/aws-cli) command line tool is used.

`./ossperf.sh -n 10 -s 524288 -b my-unique-bucketname -p -w eu-west-2`

## Related Work

Some interesting papers and software projects focusing on the performance evaluation of S3-compatible services:

- [An Evaluation of Amazon's Grid Computing Services: EC2, S3 and SQS](https://dash.harvard.edu/bitstream/handle/1/24829568/tr-08-07.pdf). *Simson Garfinkel*. 2007. *In this paper, the throughput which S3 can deliver via HTTP HET requests with objects of different sizes, is evaluated over several days from several locations by using a self-written client. The software was implemented in C++ and used [libcurl](https://curl.haxx.se/libcurl/) for the interaction with the storage service. Sadly, this client tool was never released. The focus of this work is the download performance of Amazon S3. Other operations like the the upload performance are not investigated. Unfortunately, this tool has never been released by the author.*
- [Amazon S3 for Science Grids: a Viable Solution?](http://dl.acm.org/citation.cfm?id=1383526) *Mayur Palankar, Adriana Iamnitchi, Matei Ripeanu, Simson Garfinkel*. 2008. Proceedings of the 2008 international workshop on Data-aware distributed computing (DADC 2008). Pages 55-64.
- [Real-world benchmarking of cloud storage providers: Amazon S3, Google Cloud Storage, and Azure Blob Storage](https://lg.io/2015/10/25/real-world-benchmarking-of-s3-azure-google-cloud-storage.html). *Larry Land*. 2015. *The author analyzes the performance of different public cloud object-based storage services with files of different sizes any by using the command line tools of the service providers and by mounting buckets of the services as file systems in user-space.* 
- [Windows Azure Storage: A Highly Available Cloud Storage Service with Strong Consistency](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.229.3906&rep=rep1&type=pdf). Calder et. al. 2011. *The authors describe the functioning of the Microsoft Azure Storage service offering and analyze the performance for uploading and downloading objects of 1 kB and 4 MB in size. Unfortunately, the paper provides no further details about the tool, that has been used by the authors to carry out the perforamance measurements.*
- [CloudCmp: Comparing Public Cloud Providers](http://conferences.sigcomm.org/imc/2010/papers/p1.pdf). *Li et al.*. 2010. *The authors analyzed the performance of the four public cloud service offerings Amazon S3, Microsoft Azure Blob Storage and Rackspace Cloud Files with their self developed Java software solution [CloudCmp](https://github.com/angl/cloudcmp) for objects of 1 kB and 10 MB in size. The authors among others compare the scalability of the mentioned blob services by sending multiple concurrent operations and were able to make bottlenecks visible when uploading or downloading multiple objects of 10 MB in size.* 
- [DepSky: Dependable and Secure Storage in a Cloud-of-Clouds](http://www.gsd.inesc-id.pt/~mpc/pubs/depsky-TOS-2013.pdf). *Bessani et al.*. 2013. *The authors analyzed in 2013 among others the required time to upload and download objects of 100 kB, 1 MB, and 1 0MB in size from Amazon S3, Microsoft Azure Blob Storage and Rackspace Cloud Files from clients that were located on different parts of the globe. In their work, the authors describe [DepSky](https://github.com/cloud-of-clouds/depsky), a software solution that can be used to create a virtual storage cloud by using a combination of diverse cloud service offerings in order to archive better levels of availability, security, privacy and prevent the situation of a vendor lock-in. While the DepSky software has been released to the public by the authors, they did not publish a tool to carry out performance measurements of storage services so far.*
- [AWS S3 vs Google Cloud vs Azure: Cloud Storage Performance](http://blog.zachbjornson.com/2015/12/29/cloud-storage-performance.html). *Zach Bjornson*. 2015. *The author measured the latency - time to first byte (TTFB) and the throughput of different public cloud object-based storage services by using a self-written tool. Sadly, this tool was never released.* 
- [COSBench](https://github.com/intel-cloud/cosbench) - Cloud Object Storage Benchmark. *This very complex benchmarking tool from Intel is able to measure the performance of different object-based storage services. The tool is written in Java. It provides a web-based user interface and many helpful documentation for users and developers.*
- [S3 Performance Test Tool](https://github.com/jenshadlich/S3-Performance-Test). *Jens Hadlich*. 2015/2016. *A performance test tool, which is implemented in Java and can be used to evaluate the upload and download performance of Amazon S3 or S3-compatible object storage systems.*
- [s3-perf](https://github.com/ross/s3-perf). *Ross McFarland*. 2013. *Two simple Python scripts which make use of the [boto](https://github.com/boto/boto) library to measure the download and upload data rate of the Amazon S3 service offering for different file object sizes.*

## Web Site

Visit the ossperf web page for more information and the latest revision.

[https://github.com/christianbaun/ossperf](https://github.com/christianbaun/ossperf)

Some further information provides the [Wiki](https://github.com/christianbaun/ossperf/wiki)

## License

[GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html) or later.
