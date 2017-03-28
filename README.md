# s3perf

s3perf is a lightweight command line tool for analyzing the performance and data integrity of S3-compatible storage services. The tool creates a user defined number of files with random content and of a specified size inside a local directory. The tool creates a bucket, uploads and downloads the files and afterwards removes the bucket. The time, required to carry out theses S3-related tasks is measured and printed out on command line. 

## Synopsis

`s3perf.sh -n files -s size [-k]`

## Requirements

These software packages must be installed on all worker nodes:

- bash 4.3.30
- s3cmd 1.6.1
- bc 1.06.95

## Example

This command will create five files of size 1 MB each and use them to test the performance and data integrity of the S3 service

`./s3perf.sh -n 5 -s 1048576`

## Web Site

Visit the s3perf web page for more information and the latest revision.

[https://github.com/christianbaun/s3perf](https://github.com/christianbaun/s3perf)

## License

[GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html) or later.