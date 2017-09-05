#Declare veriables
variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}
variable "region" {
  default = "ap-southeast-2""
}
variable "bucket_name" {}
variable "aws_ami" {
    default = "ami-30041c53"
}
variable "instance_profile" {
    default = "S3access"
}

#Provider
provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.region}"
}
 
#Create S3 test bucket

resource "aws_s3_bucket" "test_b" {
  bucket = "${var.bucket_name}"
  acl = "private"
  force_destroy = true
  tags {
    Name = "az test bucket"
  }
}

resource "aws_launch_configuration" "as_conf" {
  name_prefix   = "az-test-lc-"
  image_id      = "${aws_ami}"
  instance_type = "t2.micro"
  iam_instance_profile = "${var.instance_profile}"
  user_data = <<-EOF
    #!/bin/bash

    url=http://169.254.169.254/latest/meta-data
    instance_hostname = `curl -s $url/public-hostname`
    for i in ami-id instance-id instance-type hostname local-ipv4 public-hostname public-ipv4; do
        printf "%-15s%-20s\n" $i `curl -s $url/$i` >> ${instance_hostname}_instance_info.txt; done

    aws s3 cp ${instance_hostname}_instance_info.txt s3://${var.bucket_name}/${instance_hostname}_instance_info.txt --acl public-read
    EOF
    
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "az_test_asg" {
  name                 = "az-test-asg"
  launch_configuration = "${aws_launch_configuration.as_conf.name}"
  min_size             = 1
  max_size             = 1

  lifecycle {
    create_before_destroy = true
  }
}
