terraform {
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 4.0"
      }
    }
}


provider "aws" {
    profile = "default"
    region  = "us-east-1"
}


data "aws_ami" "amazon-linux-2" {
    most_recent = true
  
    filter {
      name   = "owner-alias"
      values = ["amazon"]
    }
  
    filter {
      name   = "name"
      values = ["amzn2-ami-hvm-*-x86_64-ebs"]
    }
  
}

// SSH-KEY
resource "aws_key_pair" "deployer" {
   key_name   = "deployer-key"
   public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC8OyPewfJ6G0f7fBLcdkC5xmOA23QLOD68/AYRfNt5hxBYVZqtOmJvuwVOOWfrpMueMwfTR35gbfhKheH1i1Q7+aIkDkxShc3ZF0wQnK/cemPtIbCQM2pLgBsgPtnobp15IK9dFmMUyoZvG/96rdpCU1iSRw2XTv63wLAfNCVZWCQEMWRb3Aa/rcrTt1OP8QaZuxP2qxpd1ZcDr6IavnEFOCmi7LIm6cybUI7ENyMDBhQGwwyfhnDO8MCDA0o/cwuQVdnnQuEvvoDoyHX2BmTzFaKFz60B7qHMACTZYefNMRv+CNGITMNgpoAlRTaJ1fKQh/78nS87LwB+s8yhWPtTjI04ADc4UZtlHplCxTYtsuUmPaOtKm6QwONJ73PgQztKc3Dbrvlr2c0FgsA7UI6cO0YUiYiXzwWf/AlBrms+qCAFg7mDXXOepDpEDLusF+ttLGQ/VmmrhJnsVE2AyTxjYrvkv+RJb8vTdOsLiwZRUPJn5OkJdGjG4uwRciXirfs= root@master"
} 

resource "aws_security_group" "security" {
    ingress {
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  
    ingress {
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  
    egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  
    tags = {
      Name = "allow_tls"
    } 
}
  
resource "aws_instance" "web" {
    ami           = data.aws_ami.amazon-linux-2.id
    instance_type = "t2.micro"
    key_name      = aws_key_pair.deployer.key_name
    vpc_security_group_ids = [aws_security_group.security.id]

    provisioner "local-exec" {
      command = "echo ${self.private_ip}"
    }


    provisioner "file" {
      source      = "/root/test-deployment/index.html"
      destination = "/home/ec2-user/index.html"

      connection {
        type     = "ssh"
        user     = "ec2-user"
        private_key = file("/root/.ssh/id_rsa")
        host     = aws_instance.web.public_ip
      }
    }

    provisioner "remote-exec" {
      inline = [
        "sudo yum -y update",
        "sudo yum install -y httpd",
        "sudo systemctl enable httpd && sudo service httpd restart",
        "sudo cp /home/ec2-user/index.html /var/www/html"
      ]

      connection {
        type     = "ssh"
        user     = "ec2-user"
        private_key = file("/root/.ssh/id_rsa")
        host     = aws_instance.web.public_ip
      }
    }

   tags = {
      Name = "Test-Instance"
    }
}
