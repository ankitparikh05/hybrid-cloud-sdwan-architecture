# ------------------------------------------------------
# Multicast Data Sources (Amazon Linux 2 AMI)
# ------------------------------------------------------
data "aws_ssm_parameter" "amazon_linux_2_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

# ------------------------------------------------------
# Transit Gateway Dynamic Multicast Domain (IGMPv2)
# ------------------------------------------------------
resource "aws_ec2_transit_gateway_multicast_domain" "dynamic_domain" {
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
  igmpv2_support         = "enable"
  static_sources_support = "disable"
  tags                   = { Name = "TGW-Multicast-Dynamic" }
}

# Associate VPC A Private Subnet 1 (Source)
resource "aws_ec2_transit_gateway_multicast_domain_association" "vpc_a_assoc_1" {
  subnet_id                           = module.vpc_a.private_subnet_1_id
  transit_gateway_attachment_id       = aws_ec2_transit_gateway_vpc_attachment.vpc_a_attach.id
  transit_gateway_multicast_domain_id = aws_ec2_transit_gateway_multicast_domain.dynamic_domain.id
}

# Associate VPC A Private Subnet 2 (Member 1)
resource "aws_ec2_transit_gateway_multicast_domain_association" "vpc_a_assoc_2" {
  subnet_id                           = module.vpc_a.private_subnet_2_id
  transit_gateway_attachment_id       = aws_ec2_transit_gateway_vpc_attachment.vpc_a_attach.id
  transit_gateway_multicast_domain_id = aws_ec2_transit_gateway_multicast_domain.dynamic_domain.id
}

# Associate VPC B Private Subnet 2 (Member 2)
resource "aws_ec2_transit_gateway_multicast_domain_association" "vpc_b_assoc_2" {
  subnet_id                           = module.vpc_b.private_subnet_2_id
  transit_gateway_attachment_id       = aws_ec2_transit_gateway_vpc_attachment.vpc_b_attach.id
  transit_gateway_multicast_domain_id = aws_ec2_transit_gateway_multicast_domain.dynamic_domain.id
}

# ------------------------------------------------------
# Security Groups for Multicast
# ------------------------------------------------------
resource "aws_security_group" "multicast_sg_vpc_a" {
  name        = "Multicast-SG-VPC-A"
  description = "Allow IGMP and Multicast UDP"
  vpc_id      = module.vpc_a.vpc_id

  ingress {
    description = "IGMP Query"
    protocol    = "2"
    from_port   = -1
    to_port     = -1
    cidr_blocks = ["0.0.0.0/32"]
  }

  ingress {
    description = "Multicast Application"
    protocol    = "udp"
    from_port   = 8123
    to_port     = 8123
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "multicast_sg_vpc_b" {
  name        = "Multicast-SG-VPC-B"
  description = "Allow IGMP and Multicast UDP"
  vpc_id      = module.vpc_b.vpc_id

  ingress {
    description = "IGMP Query"
    protocol    = "2"
    from_port   = -1
    to_port     = -1
    cidr_blocks = ["0.0.0.0/32"]
  }

  ingress {
    description = "Multicast Application"
    protocol    = "udp"
    from_port   = 8123
    to_port     = 8123
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------
# Network Interfaces
# ------------------------------------------------------
resource "aws_network_interface" "source_interface" {
  subnet_id       = module.vpc_a.private_subnet_1_id
  security_groups = [aws_security_group.multicast_sg_vpc_a.id]
  description     = "Primary network interface"
  tags            = { Name = "Multicast-Source" }
}

resource "aws_network_interface" "member_interface_1" {
  subnet_id       = module.vpc_a.private_subnet_2_id
  security_groups = [aws_security_group.multicast_sg_vpc_a.id]
  description     = "Primary network interface"
  tags            = { Name = "Multicast-Member-1" }
}

resource "aws_network_interface" "member_interface_2" {
  subnet_id       = module.vpc_b.private_subnet_2_id
  security_groups = [aws_security_group.multicast_sg_vpc_b.id]
  description     = "Primary network interface"
  tags            = { Name = "Multicast-Member-2" }
}

# ------------------------------------------------------
# Local Variables (Python App Bootstrapping)
# ------------------------------------------------------
locals {
  multicast_user_data = <<-EOF
    #!/bin/bash
    
    echo '# Force IGMPv2 for AWS Transit Gateway' > /etc/sysctl.d/01-multicast.conf
    echo 'net.ipv4.conf.eth0.force_igmp_version = 2' >> /etc/sysctl.d/01-multicast.conf

    cat > /usr/bin/mcast_app_install.sh<< 'INNEREOF'
    #!/bin/bash
    echo 'IyEvdXNyL2Jpbi9lbnYgcHl0aG9uCiMKIyBtY2FzdC5weSAtIFNlbmQvcmVjZWl2ZSBVRFAgbXVsdGljYXN0IHBhY2tldHMuCiMgUmVxdWlyZXMgdGhhdCB5b3VyIE9TIGtlcm5lbCBzdXBwb3J0cyBJUCBtdWx0aWNhc3QuCiMKIyBVc2FnZToKIyAgIG1jYXN0IC1zIChzZW5kZXIsIElQdjQpCiMgICBtY2FzdCAtcyAtNiAoc2VuZGVyLCBJUHY2KQojICAgbWNhc3QgKHJlY2VpdmVycywgSVB2NCkKIyAgIG1jYXN0IC02IChyZWNlaXZlcnMsIElQdjYpCiMKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCiMgQVRUUklCVVRJT04gLyBQUk9WRU5BTkNFCiMKIyBUaGlzIGZpbGUgaXMgdGhlICJtY2FzdCIgZGVtbyBmcm9tIHRoZSBDUHl0aG9uIHNvdXJjZSBkaXN0cmlidXRpb24KIyAoRGVtby9zb2NrZXRzL21jYXN0LnB5KSwgb3JpZ2luYWxseSBwdWJsaXNoZWQgYnkgdGhlIFB5dGhvbiBTb2Z0d2FyZQojIEZvdW5kYXRpb24gYXQgaHR0cHM6Ly9zdm4ucHl0aG9uLm9yZy9wcm9qZWN0cy9weXRob24vdHJ1bmsvRGVtby9zb2NrZXRzL21jYXN0LnB5CiMKIyBPcmlnaW5hbCB3b3JrIENvcHlyaWdodCAoYykgUHl0aG9uIFNvZnR3YXJlIEZvdW5kYXRpb24uIEFsbCBSaWdodHMgUmVzZXJ2ZWQuCiMgVGhlIG9yaWdpbmFsIGlzIGRpc3RyaWJ1dGVkIHVuZGVyIHRoZSBQU0YgTGljZW5zZSBBZ3JlZW1lbnQ6CiMgICBodHRwczovL2RvY3MucHl0aG9uLm9yZy8zL2xpY2Vuc2UuaHRtbAojCiMgSXQgaXMgdmVuZG9yZWQgaGVyZSAocmF0aGVyIHRoYW4gZG93bmxvYWRlZCBmcm9tIGFuIGV4dGVybmFsIHRoaXJkLXBhcnR5IGhvc3QKIyBhdCBpbnN0YW5jZSBsYXVuY2gpIHNvIHRoZSBBV1MgTmV0d29ya2luZyBXb3Jrc2hvcCBpcyBzZWxmLWNvbnRhaW5lZCBhbmQgZG9lcwojIG5vdCBkZXBlbmQgb24gdGhlIGF2YWlsYWJpbGl0eSBvZiBzdm4ucHl0aG9uLm9yZyBhdCBkZXBsb3kgdGltZS4gVGhlIGJvZHkgb2YKIyB0aGUgc2NyaXB0IGJlbG93IGlzIHVubW9kaWZpZWQgZnJvbSB0aGUgb3JpZ2luYWw7IHRoZSB3b3Jrc2hvcCBhcHBsaWVzIHRoZQojIE1ZVFRMIGFuZCBtdWx0aWNhc3QtZ3JvdXAgZWRpdHMgYXQgaW5zdGFsbCB0aW1lIHZpYSBzZWQuCiMKIyBNb2RpZmljYXRpb25zIGZvciB0aGUgQVdTIE5ldHdvcmtpbmcgV29ya3Nob3AgKHRoaXMgaGVhZGVyIG9ubHkpOgojICAgU1BEWC1MaWNlbnNlLUlkZW50aWZpZXI6IE1JVC0wCiMgICBDb3B5cmlnaHQgQW1hem9uLmNvbSwgSW5jLiBvciBpdHMgYWZmaWxpYXRlcy4gQWxsIFJpZ2h0cyBSZXNlcnZlZC4KIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tCgpNWVBPUlQgPSA4MTIzCk1ZR1JPVVBfNCA9ICcyMjUuMC4wLjI1MCcKTVlHUk9VUF82ID0gJ2ZmMTU6NzA3OTo3NDY4OjZmNmU6NjQ2NTo2ZDZmOjZkNjM6NjE3MycKTVlUVEwgPSAxICMgSW5jcmVhc2UgdG8gcmVhY2ggb3RoZXIgbmV0d29ya3MKCmltcG9ydCB0aW1lCmltcG9ydCBzdHJ1Y3QKaW1wb3J0IHNvY2tldAppbXBvcnQgc3lzCgoKZGVmIG1haW4oKToKICAgIGdyb3VwID0gTVlHUk9VUF82IGlmICItNiIgaW4gc3lzLmFyZ3ZbMTpdIGVsc2UgTVlHUk9VUF80CgogICAgaWYgIi1zIiBpbiBzeXMuYXJndlsxOl06CiAgICAgICAgc2VuZGVyKGdyb3VwKQogICAgZWxzZToKICAgICAgICByZWNlaXZlcihncm91cCkKCgpkZWYgc2VuZGVyKGdyb3VwKToKICAgIGFkZHJpbmZvID0gc29ja2V0LmdldGFkZHJpbmZvKGdyb3VwLCBOb25lKVswXQoKICAgIHMgPSBzb2NrZXQuc29ja2V0KGFkZHJpbmZvWzBdLCBzb2NrZXQuU09DS19ER1JBTSkKCiAgICAjIFNldCBUaW1lLXRvLWxpdmUgKG9wdGlvbmFsKQogICAgdHRsX2JpbiA9IHN0cnVjdC5wYWNrKCdAaScsIE1ZVFRMKQogICAgaWYgYWRkcmluZm9bMF0gPT0gc29ja2V0LkFGX0lORVQ6ICMgSVB2NAogICAgICAgIHMuc2V0c29ja29wdChzb2NrZXQuSVBQUk9UT19JUCwgc29ja2V0LklQX01VTFRJQ0FTVF9UVEwsIHR0bF9iaW4pCiAgICBlbHNlOgogICAgICAgIHMuc2V0c29ja29wdChzb2NrZXQuSVBQUk9UT19JUFY2LCBzb2NrZXQuSVBWNl9NVUxUSUNBU1RfSE9QUywgdHRsX2JpbikKCiAgICB3aGlsZSBUcnVlOgogICAgICAgIGRhdGEgPSByZXByKHRpbWUudGltZSgpKQogICAgICAgIHMuc2VuZHRvKGRhdGEgKyAnXDAnLCAoYWRkcmluZm9bNF1bMF0sIE1ZUE9SVCkpCiAgICAgICAgdGltZS5zbGVlcCgxKQoKCmRlZiByZWNlaXZlcihncm91cCk6CiAgICAjIExvb2sgdXAgbXVsdGljYXN0IGdyb3VwIGFkZHJlc3MgaW4gbmFtZSBzZXJ2ZXIgYW5kIGZpbmQgb3V0IElQIHZlcnNpb24KICAgIGFkZHJpbmZvID0gc29ja2V0LmdldGFkZHJpbmZvKGdyb3VwLCBOb25lKVswXQoKICAgICMgQ3JlYXRlIGEgc29ja2V0CiAgICBzID0gc29ja2V0LnNvY2tldChhZGRyaW5mb1swXSwgc29ja2V0LlNPQ0tfREdSQU0pCgogICAgIyBBbGxvdyBtdWx0aXBsZSBjb3BpZXMgb2YgdGhpcyBwcm9ncmFtIG9uIG9uZSBtYWNoaW5lCiAgICAjIChub3Qgc3RyaWN0bHkgbmVlZGVkKQogICAgcy5zZXRzb2Nrb3B0KHNvY2tldC5TT0xfU09DS0VULCBzb2NrZXQuU09fUkVVU0VBRERSLCAxKQoKICAgICMgQmluZCBpdCB0byB0aGUgcG9ydAogICAgcy5iaW5kKCgnJywgTVlQT1JUKSkKCiAgICBncm91cF9iaW4gPSBzb2NrZXQuaW5ldF9wdG9uKGFkZHJpbmZvWzBdLCBhZGRyaW5mb1s0XVswXSkKICAgICMgSm9pbiBncm91cAogICAgaWYgYWRkcmluZm9bMF0gPT0gc29ja2V0LkFGX0lORVQ6ICMgSVB2NAogICAgICAgIG1yZXEgPSBncm91cF9iaW4gKyBzdHJ1Y3QucGFjaygnPUknLCBzb2NrZXQuSU5BRERSX0FOWSkKICAgICAgICBzLnNldHNvY2tvcHQoc29ja2V0LklQUFJPVE9fSVAsIHNvY2tldC5JUF9BRERfTUVNQkVSU0hJUCwgbXJlcSkKICAgIGVsc2U6CiAgICAgICAgbXJlcSA9IGdyb3VwX2JpbiArIHN0cnVjdC5wYWNrKCdASScsIDApCiAgICAgICAgcy5zZXRzb2Nrb3B0KHNvY2tldC5JUFBST1RPX0lQVjYsIHNvY2tldC5JUFY2X0pPSU5fR1JPVVAsIG1yZXEpCgogICAgIyBMb29wLCBwcmludGluZyBhbnkgZGF0YSB3ZSByZWNlaXZlCiAgICB3aGlsZSBUcnVlOgogICAgICAgIGRhdGEsIHNlbmRlciA9IHMucmVjdmZyb20oMTUwMCkKICAgICAgICB3aGlsZSBkYXRhWy0xOl0gPT0gJ1wwJzoKICAgICAgICAgICAgZGF0YSA9IGRhdGFbOi0xXSAjIFN0cmlwIHRyYWlsaW5nIFwwJ3MKICAgICAgICBwcmludCAoc3RyKHNlbmRlcikgKyAnICAnICsgcmVwcihkYXRhKSkKCgppZiBfX25hbWVfXyA9PSAnX19tYWluX18nOgogICAgbWFpbigpCg==' | base64 -d > /usr/bin/mcast_app
    chmod 755 /usr/bin/mcast_app
    sed -i 's/MYTTL = 1/MYTTL = 32/g' /usr/bin/mcast_app
    sed -i 's/225.0.0.250/239.0.0.100/g' /usr/bin/mcast_app
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    yum-config-manager --enable epel
    yum install -y iperf
    INNEREOF
    chmod 755 /usr/bin/mcast_app_install.sh

    yum update -y
    yum upgrade -y
    yum install -y autoconf automake gcc git
    yum clean all
    rm -rf /var/cache/yum

    git clone https://github.com/troglobit/mcjoin.git /tmp/mcjoin
    cd /tmp/mcjoin
    ./autogen.sh
    ./configure && make
    make install-strip
    cd /tmp
    rm -rf ./*

    /bin/bash /usr/bin/mcast_app_install.sh
    reboot
  EOF
}

# ------------------------------------------------------
# EC2 Instances
# ------------------------------------------------------
resource "aws_instance" "source_instance" {
  ami                  = data.aws_ssm_parameter.amazon_linux_2_ami.value
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name # Reuses your existing IAM role
  monitoring           = true

  primary_network_interface {
    network_interface_id = aws_network_interface.source_interface.id
  }

  tags      = { Name = "Multicast-Source" }
  user_data = local.multicast_user_data
}

resource "aws_instance" "member_instance_1" {
  ami                  = data.aws_ssm_parameter.amazon_linux_2_ami.value
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  monitoring           = true

  primary_network_interface {
    network_interface_id = aws_network_interface.member_interface_1.id
  }

  tags      = { Name = "Multicast-Member-1" }
  user_data = local.multicast_user_data
}

resource "aws_instance" "member_instance_2" {
  ami                  = data.aws_ssm_parameter.amazon_linux_2_ami.value
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  monitoring           = true

  primary_network_interface {
    network_interface_id = aws_network_interface.member_interface_2.id
  }

  tags      = { Name = "Multicast-Member-2" }
  user_data = local.multicast_user_data
}

# ------------------------------------------------------
# Multicast Lab Outputs
# ------------------------------------------------------
output "multicast_source_ip" {
  description = "Multicast-Source IPv4 Address"
  value       = aws_instance.source_instance.private_ip
}

output "multicast_member_1_ip" {
  description = "Multicast-Member-1 IPv4 Address"
  value       = aws_instance.member_instance_1.private_ip
}

output "multicast_member_2_ip" {
  description = "Multicast-Member-2 IPv4 Address"
  value       = aws_instance.member_instance_2.private_ip
}
