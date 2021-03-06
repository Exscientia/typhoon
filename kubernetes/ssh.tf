locals {
  # format assets for distribution
  assets_bundle = [
    # header with the unpack location
    for key, value in module.bootstrap.assets_dist :
    format("##### %s\n%s", key, value)
  ]
}

# Secure copy assets to controllers.
resource "null_resource" "copy-controller-secrets" {
  count = var.controller_count

  depends_on = [
    module.bootstrap,
  ]

  connection {
    type        = "ssh"
    host        = aws_instance.controllers.*.private_ip[count.index]
    user        = "core"
    timeout     = "15m"
    private_key = tls_private_key.bastion.private_key_pem

    bastion_host = aws_instance.bastion.public_ip
    bastion_user = "alpine"
  }

  provisioner "file" {
    content     = join("\n", local.assets_bundle)
    destination = "$HOME/assets"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo /opt/bootstrap/layout",
    ]
  }
}

# Connect to a controller to perform one-time cluster bootstrap.
resource "null_resource" "bootstrap" {
  depends_on = [
    null_resource.copy-controller-secrets,
    module.workers,
    aws_route53_record.apiserver,
  ]

  connection {
    type        = "ssh"
    host        = aws_instance.controllers[0].private_ip
    user        = "core"
    timeout     = "15m"
    private_key = tls_private_key.bastion.private_key_pem

    bastion_host = aws_instance.bastion.public_ip
    bastion_user = "alpine"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl start bootstrap",
    ]
  }
}
