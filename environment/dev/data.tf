data "aws_availability_zones" "available" {
  state = "available"
}


data "aws_ami" "stack_ami" {
  owners      = ["self"]
  name_regex  = "^ami-stack-2"
  most_recent = true
  filter {
    name   = "name"
    values = ["ami-stack-2"]
  }
}
