variable "recreate" {
  default = 0
}

variable "update" {
  default = 0
}

variable "env" {
  type = string
}

module "protected" {
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
    module_output_id = module.protected.id
  }

  lifecycle {
    prevent_destroy = true
  }
}
