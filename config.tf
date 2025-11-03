locals {
  bastion_bootstrap = templatefile("${path.module}/scripts/bastion.sh", {

  })
}
