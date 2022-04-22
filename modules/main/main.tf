variable "prevent_destroy" {
  default = true
}

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
  count = var.prevent_destroy ? 1 : 0

  triggers = {
    module_output_id = module.protected.id
  }

  lifecycle {
    prevent_destroy = true
  }
}
