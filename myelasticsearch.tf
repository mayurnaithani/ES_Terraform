##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_name" {}
variable "region" {
  default = "ap-south-1"
}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

##################################################################################
# DATA
##################################################################################

data "aws_ami" "aws-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


##################################################################################
# RESOURCES
##################################################################################

resource "aws_default_vpc" "default" {

}

resource "aws_security_group" "es_demo" {
  name        = "demosg"
  description = "Allow access for demo"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "http"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9300
    to_port     = 9300
    protocol    = "http"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "role" {
  name = "esinstance_role"
  path = "/"

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

resource "aws_iam_instance_profile" "es_profile" {
  name = "es_profile"
  role = "${aws_iam_role.role.name}"
}

resource "aws_iam_role_policy" "es_policy" {
  name = "es_policy"
  role = "${aws_iam_role.role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:DescribeInstances"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_instance" "web" {
  count                  = 2
  ami                    = data.aws_ami.aws-linux.id
  instance_type          = "m3.2xlarge"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.es_demo.id]
  iam_instance_profile = "${aws_iam_instance_profile.es_profile.name}"
  tags {
    Name = "myesinstance_${count.index}"
  }
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_path)

  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update",
      "wget --header "Cookie: oraclelicense=accept-securebackup-cookie" \
    http://download.oracle.com/otn-pub/java/jdk/8u151-b12/e758a0de34e24606bca991d704f6dcbf/jdk-8u151-linux-x64.rpm
",
      "yum localinstall -y jdk-8u151-linux-x64.rpm",
      "rpm -i https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-5.6.3.rpm",
      "sudo chkconfig --add elasticsearch",
      "sudo service elasticsearch start"
    ]
  }
}
