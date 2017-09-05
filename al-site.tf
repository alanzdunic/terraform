/*
    AE AWS Coding Test
    Andrew Lindsay

    =====
    Notes
    =====
    I've attempted to keep things simple while still adhering to the constraints. 

    Some assumptions have been made:
      - An account with AWS defaults (VPC, security group, etc) is being used.
      - The user running terraform has privileges to create the necessary resources.
      - The bucket name provided as an argument is globally unique. If it is not,
        the 'terraform plan' will succeed but the 'apply' will fail to create a bucket.
      - The file in the S3 bucket will contain the details of the most recent instance
        created by the auto-scaling group (it gets overwritten by each new instance)
      - No ssh access to the instance is required - no key pair is configured and
        no rules added to the security group.

*/


provider "aws" {
  access_key = "${var.aws_access_key_id}"
  secret_key = "${var.aws_secret_access_key}"
  region     = "${var.aws_region}"
}

# The following args are required inputs as per spec
#
variable "aws_access_key_id" {
  description = "AWS access key id"
}

variable "aws_secret_access_key" {
  description = "AWS secret access key"
}

variable "bucket_name" {
  description = "Globally unique bucket name"
}

# The following can be provided as args but will fall back to defaults
#
variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "ap-southeast-2"
}

variable "outfile" {
  description = "Name of output file copied to S3 bucket"
  default     = "latest_instance_details.txt"
}

# Build the URL for our s3 file and provide as output
#
output "s3_file_location" {
  value = "https://s3-${var.aws_region}.amazonaws.com/${var.bucket_name}/${var.outfile}"
}

# Create the bucket in s3. The force_destroy option allows a 'terraform destroy'
# to blow it away without having to empty it first.
#
resource "aws_s3_bucket" "ae_test" {
  bucket        = "${var.bucket_name}"
  acl           = "private"
  force_destroy = true
}

# EC2 access to the S3 bucket using instance roles
#
data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = [ "sts:AssumeRole" ]

    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "s3-bucket-allow-policy" {
  statement {
    actions   = ["s3:*"]
    resources = ["${aws_s3_bucket.ae_test.arn}/*"]
  }
}

resource "aws_iam_role" "instance" {
  name = "instance_role"
  assume_role_policy = "${data.aws_iam_policy_document.instance-assume-role-policy.json}"
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

# The user-data block below writes instance meta-data to a text file, which is then
# copied to the S3 bucket using the AWS CLI utils.
#
resource "aws_launch_configuration" "ae-test" {
  image_id             = "ami-30041c53"
  instance_type        = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.profile.name}"


  user_data = <<-EOF
    #!/bin/bash

    url=http://169.254.169.254/latest/meta-data
    for i in ami-id instance-id instance-type public-ipv4; do 
      printf "%-15s%-20s\n" $i `curl -s $url/$i` >> ${var.outfile}
    done

    sleep 30 # crude way to wait for dependencies to be satisfied
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

  # only create the single instance
  min_size = 1
  max_size = 1

  tag {
    key                 = "Name"
    value               = "ae-test"
    propagate_at_launch = true
  }
}
