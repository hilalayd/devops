terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.11.0"
    }
    github = {
      source = "integrations/github"
      version = "4.23.0"
    }
  }
  
}
provider "aws" {
    region = "us-east-1"
}
provider "github" {
    token = "xxxxxxxxxxxxxxxxxxxxxx"
}
resource "github_repository" "myrepo" {
    name = "bookstore-repo"
    auto_init = true
    visibility = "private"  
}

resource "github_branch_default" "main" {
  branch = "main"
  repository = github_repository.myrepo.name
}
variable "files" {
    default = ["bookstore-api.py", "docker-compose.yml", "Dockerfile", "requirements.txt"]
  
}
resource "github_repository_file" "app-files" {
    for_each = toset(var.files)
    repository = github_repository.myrepo.name
    file = each.value
    content = file(each.value)
    branch = "main"
    commit_message = "app-files added to repo"
    overwrite_on_create = true
  
}

resource "aws_security_group" "tf-docker-sec-gr-203" {
    name = "tf-docker-sec-gr-203"
    tags = {
        Name = "tf-docker-sec-gr-203"
    }
    ingress  {
      cidr_blocks = [ "0.0.0.0/0" ]
      from_port = 22
      protocol = "tcp"
      to_port = 22
    } 
    
    ingress  {
      cidr_blocks = [ "0.0.0.0/0" ]
      from_port = 80
      protocol = "tcp"
      to_port = 80
    } 
  
    egress  {
      cidr_blocks = [ "0.0.0.0/0" ]
      from_port = 0
      protocol = "-1"
      to_port = 0
    } 
}
resource "aws_instance" "tf-docker-ec2" {
    ami = "ami-08e4e35cccc6189f4"
    instance_type = "t2.micro"
    key_name = "firstkey"
    security_groups = [ "tf-docker-sec-gr-203" ]
    tags = {
      "Name" = "web server of bookstore"
    }
    user_data  = <<-EOF
            #! /bin/bash
            yum update -y
            amazon-linux-extras install docker -y
            systemctl start docker
            systemctl enable docker
            usermod -a -G docker ec2-user
            curl -L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
            mkdir -p /home/ec2-user/bookstore-api/
            TOKEN = "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"
            FOLDER="https://$TOKEN@raw.githubusercontent.com/hilal/bookstore-repo/main/"
            curl -s --create-dirs -o "/home/ec2-user/bookstore-api/app.py" -L "$FOLDER"bookstore-app.py
            curl -s --create-dirs -o "/home/ec2-user/bookstore-api/requirements.txt" -L "$FOLDER"requirements.txt
            curl -s --create-dirs -o "/home/ec2-user/bookstore-api/Dockerfile" -L "$FOLDER"Dockerfile
            curl -s --create-dirs -o "/home/ec2-user/bookstore-api/docker-compose.yml" -L "$FOLDER"docker-compose.yml
            cd /home/ec2-user/bookstore-api
            docker build -t hilal/bookstoreapi:latest .
            docker-compose up -d
            EOF
    depends_on = [github_repository.myrepo, github_repository_file.app-files]

}


output "website" {
    value = "http://${aws_instance.tf-docker-ec2.public_dns}"

    



}