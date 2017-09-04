provider "aws" {
  access_key = "${var.aws_access_key_id}"
  secret_key = "${var.aws_secret_access_key}"
  region     = "${var.aws_region}"
}

variable "aws_access_key_id" {
  description = "AWS access key id"
}

variable "aws_secret_access_key" {
  description = "AWS secret access key"
}

variable "bucket_name" {
  description = "Globally unique bucket name"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "ap-southeast-2"
}

variable "outfile" {
  description = "Name of output file copied to S3 bucket"
  default     = "instance_details.txt"
}

output "s3_file_location" {
  value = "https://s3-${var.aws_region}.amazonaws.com/${var.bucket_name}/${var.outfile}"
}

resource "aws_s3_bucket" "ae_test" {
  bucket        = "${var.bucket_name}"
  acl           = "private"
  force_destroy = true
}

data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = [ "sts:AssumeRole" ]

    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name = "instance_role"
  assume_role_policy = "${data.aws_iam_policy_document.instance-assume-role-policy.json}"
}

data "aws_iam_policy_document" "s3-bucket-allow-policy" {
  statement {
    actions   = ["s3:*"]
    resources = ["${aws_s3_bucket.ae_test.arn}/*"]
  }
}

resource "aws_iam_policy" "policy" {
  name = "policy"
  policy = "${data.aws_iam_policy_document.s3-bucket-allow-policy.json}"
}

resource "aws_iam_policy_attachment" "policy_attach" {
  name       = "policy_attachment"
  roles      = ["${aws_iam_role.instance.name}"]
  policy_arn = "${aws_iam_policy.policy.arn}"
}

resource "aws_iam_instance_profile" "profile" {
  name = "profile"
  role = "${aws_iam_role.instance.name}"
}

resource "aws_launch_configuration" "ae-test" {
  image_id             = "ami-162c2575"
  instance_type        = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.profile.name}"
  key_name             = "MySydneyKP"

  user_data = <<-EOF
    #!/bin/bash

    url=http://169.254.169.254/latest/meta-data
    for i in instance-id instance-type public-ipv4; do 
      printf "%-15s%-20s\n" $i `curl -s $url/$i` >> ${var.outfile}
    done

    aws s3 cp ${var.outfile} s3://${var.bucket_name}/${var.outfile} --acl public-read
    EOF

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_availability_zones" "all" {}

resource "aws_autoscaling_group" "ae-test" {
  launch_configuration = "${aws_launch_configuration.ae-test.id}"
  availability_zones   = ["${data.aws_availability_zones.all.names}"]

  min_size = 1
  max_size = 1

  tag {
    key                 = "Name"
    value               = "ae-test"
    propagate_at_launch = true
  }
}
