terraform {
  source = "../..//modules/main"
}

inputs = {
  env = "dev"
  prevent_destroy = false
}
