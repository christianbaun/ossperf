# s3perf

s3perf is a lightweight command line tool for analyzing the performance and data integrity of storage services which implement the S3 API or the alternatively the Swift API. The tool creates a user defined number of files with random content and of a specified size inside a local directory. The tool creates a bucket, uploads and downloads the files and afterwards removes the bucket. The time, required to carry out theses S3/Swift-related tasks is measured and printed out on command line. 

Storage services tested with this tool are so far:
- [Amazon Simple Storage Service (S3)](https://aws.amazon.com/s3/)
- [Google Cloud Storage (GCS)](https://cloud.google.com/storage/)
- [Nimbus Cumulus](https://github.com/nimbusproject/nimbus)
- [Minio](https://github.com/minio/minio)
- [S3ninja](https://github.com/scireum/s3ninja/)
- [S3rver](https://github.com/jamhall/s3rver/)
- [Fake S3](https://github.com/jubos/fake-s3)
- [Scality S3](https://github.com/scality/S3)
- [Riak CS](https://github.com/basho/riak_cs)
- [OpenStack Swift](https://github.com/openstack/swift)


## Synopsis

    s3perf.sh -n files -s size [-u] [a] [-k] [-p]

    Arguments:
    -h : show this message on screen
    -n : number of files to be created
    -s : size of the files to be created in bytes (max 16777216 = 16 MB)
    -u : use upper-case letters for the bucket name (this is required for Nimbus Cumulus and S3ninja)
    -a : use the Swift API and not the S3 API (this requires the python client for the Swift API and the environment variables ST_AUTH, ST_USER and ST_KEY)
    -k : keep the local files and the directory afterwards (do not clean up)
    -p : upload and download the files in parallel

## Requirements

These software packages must be installed on all worker nodes:

- bash 4.3.30
- s3cmd 1.6.1
- bc 1.06.95
- parallel 20130922

## Example

This command will create five files of size 1 MB each and use them to test the performance and data integrity of the storage service. The uploads and the downloads will be carried out in parallel.

`./s3perf.sh -n 5 -s 1048576 -p`

## Related Work

Some interesting papers and software projects focusing the performance evaluation of S3-compatible services.

- [An Evaluation of Amazon's Grid Computing Services: EC2, S3 and SQS](https://dash.harvard.edu/bitstream/handle/1/24829568/tr-08-07.pdf). *Simson Garfinkel*. 2007. *In this paper, the throughput which S3 can deliver with objects of different sizes, is evaluated over several days from several locations by using a self-written tool. Sadly, this tool was never released.*
- [Amazon S3 for Science Grids: a Viable Solution?](http://dl.acm.org/citation.cfm?id=1383526) *Mayur Palankar, Adriana Iamnitchi, Matei Ripeanu, Simson Garfinkel*. 2008. Proceedings of the 2008 international workshop on Data-aware distributed computing (DADC 2008). Pages 55-64.
- [Real-world benchmarking of cloud storage providers: Amazon S3, Google Cloud Storage, and Azure Blob Storage](https://lg.io/2015/10/25/real-world-benchmarking-of-s3-azure-google-cloud-storage.html). *Larry Land*. 2015. *The author analyzes the performance of different public cloud object-based storage services with files of different sizes any by using the command line tools of the service providers and by mounting buckets of the services as file systems in user-space.* 
- [AWS S3 vs Google Cloud vs Azure: Cloud Storage Performance](http://blog.zachbjornson.com/2015/12/29/cloud-storage-performance.html). *Zach Bjornson*. 2015. *The author measured the latency - time to first byte (TTFB) and the throughput of different public cloud object-based storage services by using a self-written tool. Sadly, this tool was never released.* 
- [COSBench](https://github.com/intel-cloud/cosbench) - Cloud Object Storage Benchmark. *This very complex benchmarking tool from Intel is able to measure the performance of different object-based storage services. The tool is written in Java. It provides a web-based user interface and many helpful documentation for users and developers.*
- [s3-perf](https://github.com/ross/s3-perf). *Ross McFarland*. 2013. *Two simple Python scripts which make use of the [boto](https://github.com/boto/boto) library to measure the download and upload data rate of the Amazon S3 service offering for different file object sizes.*

## Web Site

Visit the s3perf web page for more information and the latest revision.

[https://github.com/christianbaun/s3perf](https://github.com/christianbaun/s3perf)

Some further information provides the [Wiki](https://github.com/christianbaun/s3perf/wiki)

## License

[GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html) or later.
