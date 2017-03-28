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

## Interesting Sources about the performance evaluation of S3-compatible services

- Amazon S3 for Science Grids: a Viable Solution? *Mayur Palankar, Adriana Iamnitchi, Matei Ripeanu, Simson Garfinkel*. 2008. ([source](http://dl.acm.org/citation.cfm?id=1383526))
- An Evaluation of Amazon's Grid Computing Services: EC2, S3 and SQS. *Simson Garfinkel*. 2007. ([source](https://dash.harvard.edu/bitstream/handle/1/24829568/tr-08-07.pdf))
- s3-perf. *Ross McFarland*. 2013. ([source](https://github.com/ross/s3-perf)). 

## Web Site

Visit the s3perf web page for more information and the latest revision.

[https://github.com/christianbaun/s3perf](https://github.com/christianbaun/s3perf)

## License

[GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html) or later.