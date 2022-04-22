variable "name" {
  description = "Security group name; forces new resource"
}

variable "tag" {
  description = "Test tag value"
}

provider "aws" {
  region  = "us-east-1"
  profile = "personal"
}

resource "aws_security_group" "this" {
  name = var.name
  tags = {
    TestTag : var.tag
  }
}

output "id" {
  value = aws_security_group.this.id
}
