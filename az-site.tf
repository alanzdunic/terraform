/*
    AE AWS Coding Test
    Alan Zdunic
    Date: 05/09/2017

    =====
    Notes
    =====
    I've tried to keep things simple so made some assumptions:
      - An account with AWS defaults (VPC, security group, etc) is being used and user has sufficient privileges to create needed resources and perform actions.
      - Default AWS AMI and region.
      - IAM EC2 - S3 role exist.
      - The bucket name provided by user as an argument is globally unique.   
      - Only one instance is required in the auto-scaling group. 
      - No ssh access to the instance is required - no key pair is configured and
        no rules added to the security group.
*/

# Declare veriables
variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}
variable "region" {
  default = "ap-southeast-2"
}
variable "bucket_name" {}
variable "aws_ami" {
    default = "ami-30041c53"
}
variable "instance_profile" {
    default = "S3access"
}

# Provider
provider "aws" {
    access_key = "${var.aws_access_key_id}"
    secret_key = "${var.aws_secret_access_key}"
    region = "${var.region}"
}
 
# Create S3 test bucket

resource "aws_s3_bucket" "test_b" {
  bucket = "${var.bucket_name}"
  acl = "private"
  force_destroy = true
  tags {
    Name = "az test bucket"
  }
}

# Create lc and asg
resource "aws_launch_configuration" "as_conf" {
  name_prefix   = "az-test-lc-"
  image_id      = "${var.aws_ami}"
  instance_type = "t2.micro"
  iam_instance_profile = "${var.instance_profile}"
  
  user_data = <<-EOF
    #!/bin/bash

    url=http://169.254.169.254/latest/meta-data
    instance_file=`curl -s $url/public-hostname`_instance_info.txt
    for i in ami-id instance-id instance-type hostname local-ipv4 public-hostname public-ipv4; do
        printf "%-20s%-25s\n" $i `curl -s $url/$i` >> $instance_file; done

    aws s3 cp $instance_file s3://${var.bucket_name}/$instance_file --acl public-read
    EOF
    
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_availability_zones" "all" {}

resource "aws_autoscaling_group" "az_test_asg" {
  name                 = "az-test-asg"
  launch_configuration = "${aws_launch_configuration.as_conf.name}"
  availability_zones   = ["${data.aws_availability_zones.all.names}"]
  
  min_size             = 1
  max_size             = 1

  lifecycle {
    create_before_destroy = true
  }
}
