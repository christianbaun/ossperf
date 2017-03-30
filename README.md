# s3perf

s3perf is a lightweight command line tool for analyzing the performance and data integrity of S3-compatible storage services. The tool creates a user defined number of files with random content and of a specified size inside a local directory. The tool creates a bucket, uploads and downloads the files and afterwards removes the bucket. The time, required to carry out theses S3-related tasks is measured and printed out on command line. 

## Synopsis

`s3perf.sh -n files -s size [-k] [-p]`

## Requirements

These software packages must be installed on all worker nodes:

- bash 4.3.30
- s3cmd 1.6.1
- bc 1.06.95
- parallel 20130922

## Example

This command will create five files of size 1 MB each and use them to test the performance and data integrity of the S3 service

`./s3perf.sh -n 5 -s 1048576`

## Interesting Sources about the performance evaluation of S3-compatible services

- [An Evaluation of Amazon's Grid Computing Services: EC2, S3 and SQS](https://dash.harvard.edu/bitstream/handle/1/24829568/tr-08-07.pdf). *Simson Garfinkel*. 2007. *In this paper, the throughput which S3 can deliver with objects of different sizes, is evaluated over several days from several locations by using a self-written tool. Sadly, this tool was never released.*
- [Amazon S3 for Science Grids: a Viable Solution?](http://dl.acm.org/citation.cfm?id=1383526) *Mayur Palankar, Adriana Iamnitchi, Matei Ripeanu, Simson Garfinkel*. 2008. Proceedings of the 2008 international workshop on Data-aware distributed computing (DADC 2008). Pages 55-64.
- [Real-world benchmarking of cloud storage providers: Amazon S3, Google Cloud Storage, and Azure Blob Storage](https://lg.io/2015/10/25/real-world-benchmarking-of-s3-azure-google-cloud-storage.html). *Larry Land*. 2015. *The author analyzes the performance of different public cloud object-based storage services whith files of different sizes any by using the command line tools of the service providers and by mounting buckets of the services as file systems in user-space.* 
- [AWS S3 vs Google Cloud vs Azure: Cloud Storage Performance](http://blog.zachbjornson.com/2015/12/29/cloud-storage-performance.html). *Zach Bjornson*. 2015. *The author measured the latency - time to first byte (TTFB) and the throughput of different public cloud object-based storage services by using a self-written tool. Sadly, this tool was never released.* 
- [COSBench](https://github.com/intel-cloud/cosbench) - Cloud Object Storage Benchmark. *This very complex benchmarking tool from Intel is able to measure the performance of different object-based storage services. The tool is written in Java. It provides a web-based user interface and many helpful documentation for users and developers.*
- [s3-perf](https://github.com/ross/s3-perf). *Ross McFarland*. 2013. *Two simple Python scripts which make use of the [boto](https://github.com/boto/boto) library to measure the download and upload data rate of the Amazon S3 service offering for different file object sizes.*

## Web Site

Visit the s3perf web page for more information and the latest revision.

[https://github.com/christianbaun/s3perf](https://github.com/christianbaun/s3perf)

## License

[GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html) or later.
