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

#Provider
provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.region}"
}

#IAM 
 
#S3access

resource "aws_iam_instance_profile" "s3access" {
    name = "s3access"
    roles = ["${aws_iam_role.s3_access.name}"]
}

resource "aws_iam_role_policy" "s3access_policy" {
    name = "s3access_policy"
    role = "${aws_iam_role.s3access.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "s3access" {
    name = "s3access"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
  {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
  },
      "Effect": "Allow",
      "Sid": ""
      }
    ]
}
EOF
}

#S3 test bucket

resource "aws_s3_bucket" "test_b" {
  bucket = "${var.bucket_name}"
  acl = "private"
  force_destroy = true
  tags {
    Name = "test bucket"
  }
}

resource "aws_launch_configuration" "as_conf" {
  name_prefix   = "az-test-lc-"
  image_id      = "${aws_ami}"
  instance_type = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.s3access.id}"
  user_data = <<-EOF
    #!/bin/bash

    url=http://169.254.169.254/latest/meta-data
    instance_hostname = `curl -s $url/public-hostname`
    for i in ami-id instance-id instance-type hostname local-ipv4 public-hostname public-ipv4; do 
      printf "%-15s%-20s\n" $i `curl -s $url/$i` >> $instane_hostname-instance_info.txt
    done

    aws s3 cp instance_info.txt s3://${var.bucket_name}/${var.outfile} --acl public-read
    EOF
    
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "bar" {
  name                 = "az-test-asg"
  launch_configuration = "${aws_launch_configuration.as_conf.name}"
  min_size             = 1
  max_size             = 2

  lifecycle {
    create_before_destroy = true
  }
}
