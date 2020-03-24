provider "aws" {
  region = var.region
  profile = var.profile
}

provider "github" {
  token = var.github_token
  organization = ""
  version = "~> 2.1.0"
}

data "github_user" "ssh" {
  count = length(var.gh_users_ssh)
  username = var.gh_users_ssh[count.index]
}

locals {
  authorized_keys = flatten(data.github_user.ssh.*.ssh_keys)
}

data "template_file" "authorized_keys" {
  count = length(local.authorized_keys)
  template = "    - $${authorized_key}"
  vars = {
    authorized_key = local.authorized_keys[count.index]
  }
}

data "template_file" "setup_shadowsocks" {
  template = file("./scripts/provision.sh")
  vars = {
    password = var.password
  }
}

data "template_cloudinit_config" "config" {
  gzip = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = data.template_file.setup_shadowsocks.rendered
  }

  part {
    filename = "init.cfg"
    content_type = "text/cloud-config"
    content = <<EOF
ssh_authorized_keys:
${join("\n", data.template_file.authorized_keys.*.rendered)}
EOF
  }
}


resource "aws_instance" "ssocks" {
  count = 1
  # number of copies to spin up - if you put 1000 here, your bill might surprise you...
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  user_data_base64 = data.template_cloudinit_config.config.rendered

  security_groups = [
    aws_security_group.ssh_https.name
  ]
}

resource "aws_security_group" "ssh_https" {
  name = "ssh_https"
  description = "Allow all inbound traffic"

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  tags = {
    Name = "ssh_https"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"
    values = [
      "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  owners = [
    "099720109477"]
  # Canonical
}

output "public_dns" {
  value = aws_instance.ssocks.*.public_dns
}

output "public_ip" {
  value = aws_instance.ssocks.*.public_ip
}


data "aws_route53_zone" "primary" {
  count = var.create_dns_record ? 1 : 0
  name = var.domain
}

resource "aws_route53_record" "vpn" {
  count = var.create_dns_record ? 1 : 0
  zone_id = data.aws_route53_zone.primary[0].zone_id
  name = var.host
  type = "A"
  ttl = 300
  records = aws_instance.ssocks.*.public_ip
}