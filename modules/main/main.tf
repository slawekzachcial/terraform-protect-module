variable "recreate" {
  default = 0
}

variable "update" {
  default = 0
}

variable "env" {
  type = string
}

module "security_group" {
  source = "../aws_security_group"

  name = "TestSecurityGroup-${var.env}-${var.recreate}"
  tag  = "Value-${var.env}-${var.update}"
}

resource "null_resource" "module_guardian" {
  # Using count: will name resource, if created, null_resource.module_guardian[0]
  count = var.env == "pro" ? 1 : 0

  # Using for_each: will name resource, if created, null_resource.module_guardian["pro"]
  # for_each = toset([for e in [var.env] : e if e == "pro"])

  triggers = {
    security_group_id = module.security_group.group_id
  }

  lifecycle {
    prevent_destroy = true
  }
}
