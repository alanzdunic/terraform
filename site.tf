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
S3_access 

#Create S3 bucket
resource "aws_s3_bucket" "b" {
  bucket = "${var.bucket_name}"
  acl    = "public"

  tags {
    Name        = "az-test-bucket"
  }
}

resource "aws_launch_configuration" "as_conf" {
  name_prefix   = "az-test-lc-"
  image_id      = "${aws_ami}"
  instance_type = "t2.micro"

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
