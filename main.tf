# Description: Create IAM roles for EC2 instances

# ------------------------------------------------------
# IAM Roles & Instance Profile
# ------------------------------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "NetworkingWorkshopEC2Role"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "NetworkingWorkshopInstanceProfile"
  path = "/"
  role = aws_iam_role.ec2_role.name
}

# ------------------------------------------------------
# Core Spoke VPC Modules (VPC A, B, and C)
# ------------------------------------------------------
module "vpc_a" {
  source                = "./modules/spoke_vpc"
  vpc_name              = "VPC A"
  cidr_block            = "10.0.0.0/16"
  az_a                  = var.availability_zone_a
  az_b                  = var.availability_zone_b
  ami_id                = data.aws_ssm_parameter.latest_ami.value
  instance_profile_name = aws_iam_instance_profile.ec2_instance_profile.name
  server_ip             = "10.0.1.100"
  create_public_server  = true
  public_server_ip      = "10.0.2.100"

  subnet_cidrs = {
    pub_1  = "10.0.0.0/24"
    pub_2  = "10.0.2.0/24"
    priv_1 = "10.0.1.0/24"
    priv_2 = "10.0.3.0/24"
    tgw_1  = "10.0.5.0/28"
    tgw_2  = "10.0.5.16/28"
  }
}

module "vpc_b" {
  source                = "./modules/spoke_vpc"
  vpc_name              = "VPC B"
  cidr_block            = "10.1.0.0/16"
  az_a                  = var.availability_zone_a
  az_b                  = var.availability_zone_b
  ami_id                = data.aws_ssm_parameter.latest_ami.value
  instance_profile_name = aws_iam_instance_profile.ec2_instance_profile.name
  server_ip             = "10.1.1.100"

  subnet_cidrs = {
    pub_1  = "10.1.0.0/24"
    pub_2  = "10.1.2.0/24"
    priv_1 = "10.1.1.0/24"
    priv_2 = "10.1.3.0/24"
    tgw_1  = "10.1.5.0/28"
    tgw_2  = "10.1.5.16/28"
  }
}

module "vpc_c" {
  source                = "./modules/spoke_vpc"
  vpc_name              = "VPC C"
  cidr_block            = "10.2.0.0/16"
  az_a                  = var.availability_zone_a
  az_b                  = var.availability_zone_b
  ami_id                = data.aws_ssm_parameter.latest_ami.value
  instance_profile_name = aws_iam_instance_profile.ec2_instance_profile.name
  server_ip             = "10.2.1.100"

  subnet_cidrs = {
    pub_1  = "10.2.0.0/24"
    pub_2  = "10.2.2.0/24"
    priv_1 = "10.2.1.0/24"
    priv_2 = "10.2.3.0/24"
    tgw_1  = "10.2.5.0/28"
    tgw_2  = "10.2.5.16/28"
  }
}

# ------------------------------------------------------
# Transit Gateway & Module Attachments
# ------------------------------------------------------
resource "aws_ec2_transit_gateway" "tgw" {
  description                     = "Networking Workshop TGW"
  amazon_side_asn                 = 64512
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  multicast_support               = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"
  transit_gateway_cidr_blocks     = ["10.10.0.0/24"]
  tags                            = { Name = "TGW" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_a_attach" {
  subnet_ids         = module.vpc_a.tgw_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = module.vpc_a.vpc_id
  tags               = { Name = "VPC A Attachment" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_b_attach" {
  subnet_ids         = module.vpc_b.tgw_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = module.vpc_b.vpc_id
  tags               = { Name = "VPC B Attachment" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_c_attach" {
  subnet_ids         = module.vpc_c.tgw_subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = module.vpc_c.vpc_id
  tags               = { Name = "VPC C Attachment" }
}

# ------------------------------------------------------
# Consolidated TGW Routes using for_each
# ------------------------------------------------------
# VPC A Public Subnet Routes to TGW
resource "aws_route" "vpc_a_public_tgw" {
  for_each               = toset(["10.1.0.0/16", "10.2.0.0/16", "10.5.0.0/16", "172.16.0.0/16", "172.20.0.0/16"])
  route_table_id         = module.vpc_a.public_rt_id
  destination_cidr_block = each.value
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.vpc_a_attach]
}

# VPC A Private Subnet Routes to TGW
resource "aws_route" "vpc_a_private_tgw" {
  for_each               = toset(["10.1.0.0/16", "10.2.0.0/16", "10.5.0.0/16", "172.16.0.0/16", "172.20.0.0/16"])
  route_table_id         = module.vpc_a.private_rt_id
  destination_cidr_block = each.value
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.vpc_a_attach]
}

# VPC B Private Subnet Routes to TGW
resource "aws_route" "vpc_b_private_tgw" {
  for_each               = toset(["10.0.0.0/16", "10.2.0.0/16", "10.5.0.0/16", "172.16.0.0/16", "172.20.0.0/16"])
  route_table_id         = module.vpc_b.private_rt_id
  destination_cidr_block = each.value
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.vpc_b_attach]
}

# VPC C Private Subnet Routes to TGW
resource "aws_route" "vpc_c_private_tgw" {
  for_each               = toset(["10.0.0.0/16", "10.1.0.0/16", "10.5.0.0/16", "172.16.0.0/16", "172.20.0.0/16"])
  route_table_id         = module.vpc_c.private_rt_id
  destination_cidr_block = each.value
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.vpc_c_attach]
}

# ------------------------------------------------------
# Route53 Outbound Resolver
# ------------------------------------------------------
resource "aws_security_group" "r53_outbound_sg" {
  name        = "Route53-Outbound-Endpoint-SG"
  description = "Allow outbound DNS traffic to on-prem"
  vpc_id      = module.vpc_a.vpc_id

  egress {
    protocol    = "udp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = ["172.16.0.0/16"]
  }

  egress {
    protocol    = "tcp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = ["172.16.0.0/16"]
  }
}

resource "aws_route53_resolver_endpoint" "outbound" {
  name               = "NetworkingDayOutbound"
  direction          = "OUTBOUND"
  security_group_ids = [aws_security_group.r53_outbound_sg.id]

  ip_address {
    subnet_id = module.vpc_a.private_subnet_1_id
  }

  ip_address {
    subnet_id = module.vpc_a.private_subnet_2_id
  }

  tags = { Name = "NetworkingDayOutbound" }
}

resource "aws_route53_resolver_rule" "example_corp" {
  name                 = "NetworkingDayRule"
  domain_name          = "example.corp."
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id

  target_ip {
    ip = "172.16.1.200"
  }
}

resource "aws_route53_resolver_rule_association" "vpc_a_assoc" {
  resolver_rule_id = aws_route53_resolver_rule.example_corp.id
  vpc_id           = module.vpc_a.vpc_id
}

resource "aws_route53_resolver_rule_association" "vpc_b_assoc" {
  resolver_rule_id = aws_route53_resolver_rule.example_corp.id
  vpc_id           = module.vpc_b.vpc_id
}

resource "aws_route53_resolver_rule_association" "vpc_c_assoc" {
  resolver_rule_id = aws_route53_resolver_rule.example_corp.id
  vpc_id           = module.vpc_c.vpc_id
}

# ------------------------------------------------------
# On-Premises VPC & Hybrid Networking
# ------------------------------------------------------
resource "aws_vpc" "on_prem_vpc" {
  cidr_block           = var.on_prem_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "On Premises" }
}

resource "aws_subnet" "on_prem_private_subnet" {
  vpc_id                  = aws_vpc.on_prem_vpc.id
  cidr_block              = var.on_prem_private_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags = {
    Name       = "On-Premises Private Subnet"
    SubnetType = "Private"
  }
}

resource "aws_subnet" "on_prem_public_subnet" {
  vpc_id                  = aws_vpc.on_prem_vpc.id
  cidr_block              = var.on_prem_public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags = {
    Name       = "On-Premises Public Subnet"
    SubnetType = "Public"
  }
}

resource "aws_internet_gateway" "on_prem_igw" {
  vpc_id = aws_vpc.on_prem_vpc.id
  tags   = { Name = "On-Premises IGW" }
}

resource "aws_eip" "on_prem_nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "on_prem_natgw" {
  allocation_id = aws_eip.on_prem_nat_eip.id
  subnet_id     = aws_subnet.on_prem_public_subnet.id
  tags          = { Name = "On-Premises NATGW" }
  depends_on    = [aws_internet_gateway.on_prem_igw]
}

resource "aws_route_table" "on_prem_public_rt" {
  vpc_id = aws_vpc.on_prem_vpc.id
  tags = {
    Name    = "On-Premises Public Route Table"
    Network = "Public"
  }
}

resource "aws_route" "on_prem_public_route" {
  route_table_id         = aws_route_table.on_prem_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.on_prem_igw.id
}

resource "aws_route_table_association" "on_prem_public_assoc" {
  subnet_id      = aws_subnet.on_prem_public_subnet.id
  route_table_id = aws_route_table.on_prem_public_rt.id
}

resource "aws_route_table" "on_prem_private_rt" {
  vpc_id = aws_vpc.on_prem_vpc.id
  tags = {
    Name    = "On-Premises Private Route Table"
    Network = "Private"
  }
}

resource "aws_route" "on_prem_private_route_nat" {
  route_table_id         = aws_route_table.on_prem_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.on_prem_natgw.id
}

resource "aws_route" "on_prem_private_route_aws" {
  route_table_id         = aws_route_table.on_prem_private_rt.id
  destination_cidr_block = "10.0.0.0/8"
  network_interface_id   = aws_instance.on_prem_cgw.primary_network_interface_id
}

resource "aws_route" "on_prem_private_to_branch1" {
  route_table_id         = aws_route_table.on_prem_private_rt.id
  destination_cidr_block = "172.20.0.0/16"
  network_interface_id   = aws_instance.on_prem_cgw.primary_network_interface_id
}

resource "aws_route_table_association" "on_prem_private_assoc" {
  subnet_id      = aws_subnet.on_prem_private_subnet.id
  route_table_id = aws_route_table.on_prem_private_rt.id
}

resource "aws_eip" "on_prem_cgw_eip" {
  domain = "vpc"
}

resource "aws_customer_gateway" "on_prem_cgw" {
  bgp_asn    = 65000
  ip_address = aws_eip.on_prem_cgw_eip.public_ip
  type       = "ipsec.1"
  tags       = { Name = "On-Premises-Customer-Gateway" }
}

resource "aws_eip_association" "on_prem_cgw_eip_assoc" {
  instance_id   = aws_instance.on_prem_cgw.id
  allocation_id = aws_eip.on_prem_cgw_eip.id
}

resource "aws_vpn_connection" "tgw_vpn" {
  customer_gateway_id = aws_customer_gateway.on_prem_cgw.id
  transit_gateway_id  = aws_ec2_transit_gateway.tgw.id
  type                = aws_customer_gateway.on_prem_cgw.type
  static_routes_only  = false
  tags                = { Name = "On-Prem-to-TGW-VPN" }
}

# ------------------------------------------------------
# On-Premises Security Groups & Instances
# ------------------------------------------------------
resource "aws_security_group" "on_prem_app_server_sg" {
  name        = "On-Premises App Server Security Group"
  description = "Security group for app server"
  vpc_id      = aws_vpc.on_prem_vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  ingress {
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "on_prem_dns_server_sg" {
  name        = "On-Premises DNS Server Security Group"
  description = "Security group for DNS server"
  vpc_id      = aws_vpc.on_prem_vpc.id

  ingress {
    protocol    = "udp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  ingress {
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "on_prem_cgw_sg" {
  name        = "On-Premises Customer Gateway Security Group"
  description = "Security group for Customer Gateway Server"
  vpc_id      = aws_vpc.on_prem_vpc.id

  ingress {
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  ingress {
    description = "Allow IKE from AWS VPN Tunnels"
    protocol    = "udp"
    from_port   = 500
    to_port     = 500
    cidr_blocks = [
      "${aws_vpn_connection.tgw_vpn.tunnel1_address}/32",
      "${aws_vpn_connection.tgw_vpn.tunnel2_address}/32"
    ]
  }

  ingress {
    description = "Allow NAT-T from AWS VPN Tunnels"
    protocol    = "udp"
    from_port   = 4500
    to_port     = 4500
    cidr_blocks = [
      "${aws_vpn_connection.tgw_vpn.tunnel1_address}/32",
      "${aws_vpn_connection.tgw_vpn.tunnel2_address}/32"
    ]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "on_prem_app_server" {
  ami                    = data.aws_ssm_parameter.latest_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.on_prem_private_subnet.id
  private_ip             = "172.16.1.100"
  vpc_security_group_ids = [aws_security_group.on_prem_app_server_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  depends_on = [
    aws_route.on_prem_private_route_nat,
    aws_route.on_prem_public_route,
    aws_route_table_association.on_prem_public_assoc,
    aws_route_table_association.on_prem_private_assoc
  ]

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    for i in {1..30}; do
      if curl -sI --connect-timeout 2 https://aws.amazon.com > /dev/null; then
        break
      fi
      sleep 3
    done

    dnf install -y httpd
    echo "Hello, world." > /var/www/html/index.html
    systemctl enable httpd.service
    systemctl start httpd.service
  EOF

  tags = { Name = "On-Premises App Server" }
}

resource "aws_instance" "on_prem_dns_server" {
  ami                    = data.aws_ssm_parameter.latest_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.on_prem_private_subnet.id
  private_ip             = "172.16.1.200"
  vpc_security_group_ids = [aws_security_group.on_prem_dns_server_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  depends_on = [
    aws_route.on_prem_private_route_nat,
    aws_route.on_prem_public_route,
    aws_route_table_association.on_prem_public_assoc,
    aws_route_table_association.on_prem_private_assoc,
    aws_instance.on_prem_app_server
  ]

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    for i in {1..30}; do
      if curl -sI --connect-timeout 2 https://aws.amazon.com > /dev/null; then
        break
      fi
      sleep 3
    done

    dnf install -y bind

    cat > /etc/named.conf << 'INNEREOF'
    options {
      directory       "/var/named";
      dump-file       "/var/named/data/cache_dump.db";
      statistics-file "/var/named/data/named_stats.txt";
      memstatistics-file "/var/named/data/named_mem_stats.txt";
      recursing-file  "/var/named/data/named.recursing";
      secroots-file   "/var/named/data/named.secroots";

      recursion yes;
      allow-query { any; };
      dnssec-validation no;

      bindkeys-file "/etc/named.root.key";
      managed-keys-directory "/var/named/dynamic";
      pid-file "/run/named/named.pid";
      session-keyfile "/run/named/session.key";

      forwarders {
              169.254.169.253;
      };
      forward first;
    };

    logging {
      channel default_debug {
            file "data/named.run";
            severity dynamic;
      };
    };

    zone "." IN {
            type hint;
            file "named.ca";
    };

    zone "example.corp" IN {
            type master;
            file "/etc/named/example.corp";
            allow-update { none; };
    };

    include "/etc/named.rfc1912.zones";
    include "/etc/named.root.key";
    INNEREOF

    mkdir -p /etc/named

    cat > /etc/named/example.corp << 'INNEREOF'
    $ORIGIN example.corp.
    @                      3600 IN SOA ns1.example.corp. zone-admin.example.corp. (
                                  2026100901                 ; serial number
                                  3600                       ; refresh period
                                  600                        ; retry period
                                  604800                     ; expire time
                                  1800                     ) ; minimum ttl
                          86400 IN NS  ns1.example.corp.
    myapp                    60 IN A   ${aws_instance.on_prem_app_server.private_ip}
    ns1                      60 IN A   172.16.1.200
    INNEREOF

    named-checkconf /etc/named.conf
    named-checkzone example.corp /etc/named/example.corp

    systemctl enable named.service
    systemctl start named.service

    cat > /etc/resolv.conf << 'INNEREOF'
    search example.corp
    nameserver 127.0.0.1
    INNEREOF
  EOF

  tags = { Name = "On-Premises DNS Server" }
}

resource "aws_vpc_dhcp_options" "on_prem_dhcp" {
  domain_name         = "example.corp"
  domain_name_servers = [aws_instance.on_prem_dns_server.private_ip]
  tags                = { Name = "On-Premises DHCP Options" }
}

resource "aws_vpc_dhcp_options_association" "on_prem_dhcp_assoc" {
  vpc_id          = aws_vpc.on_prem_vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.on_prem_dhcp.id
}

locals {
  on_prem_cgw_private_ip = "172.16.0.100"
}

resource "aws_instance" "on_prem_cgw" {
  ami                    = data.aws_ssm_parameter.latest_ami_cgw.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.on_prem_public_subnet.id
  private_ip             = local.on_prem_cgw_private_ip
  vpc_security_group_ids = [aws_security_group.on_prem_cgw_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
  source_dest_check      = false

  depends_on = [
    aws_route.on_prem_public_route,
    aws_vpc_dhcp_options_association.on_prem_dhcp_assoc
  ]

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    
    while ! curl -sI https://aws.amazon.com > /dev/null; do
      echo "Waiting for internet connection and DNS resolution..."
      sleep 5
    done
    
    dnf update -y
    dnf install -y spal-release
    dnf install -y libreswan frr
    
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    echo "net.ipv4.conf.default.rp_filter = 0" >> /etc/sysctl.conf
    echo "net.ipv4.conf.default.accept_source_route = 0" >> /etc/sysctl.conf
    echo "net.ipv4.conf.all.rp_filter = 0" >> /etc/sysctl.conf
    sysctl -p

    ip route replace 172.16.0.0/16 via 172.16.0.1

    cat > /etc/ipsec.d/aws.conf << 'INNEREOF'
    conn Tunnel1
        authby=secret
        auto=start
        left=%defaultroute
        leftid=${aws_eip.on_prem_cgw_eip.public_ip}
        right=${aws_vpn_connection.tgw_vpn.tunnel1_address}
        type=tunnel
        ikev2=yes
        ike=aes256-sha2_256;dh14
        ikelifetime=8h
        keylife=1h
        phase2alg=aes_gcm
        keyingtries=%forever
        leftsubnet=0.0.0.0/0
        rightsubnet=0.0.0.0/0
        dpddelay=10
        dpdtimeout=30
        dpdaction=restart
        mark=100/0xffffffff
        vti-interface=vti1
        leftvti=${aws_vpn_connection.tgw_vpn.tunnel1_cgw_inside_address}/30
        vti-routing=no

    conn Tunnel2
        authby=secret
        auto=start
        left=%defaultroute
        leftid=${aws_eip.on_prem_cgw_eip.public_ip}
        right=${aws_vpn_connection.tgw_vpn.tunnel2_address}
        type=tunnel
        ikev2=yes
        ike=aes256-sha2_256;dh14
        ikelifetime=8h
        keylife=1h
        phase2alg=aes_gcm
        keyingtries=%forever
        leftsubnet=0.0.0.0/0
        rightsubnet=0.0.0.0/0
        dpddelay=10
        dpdtimeout=30
        dpdaction=restart
        mark=200/0xffffffff
        vti-interface=vti2
        leftvti=${aws_vpn_connection.tgw_vpn.tunnel2_cgw_inside_address}/30
        vti-routing=no
    INNEREOF

    cat > /etc/ipsec.d/aws.secrets << 'INNEREOF'
    ${aws_eip.on_prem_cgw_eip.public_ip} ${aws_vpn_connection.tgw_vpn.tunnel1_address} : PSK "${aws_vpn_connection.tgw_vpn.tunnel1_preshared_key}"
    ${aws_eip.on_prem_cgw_eip.public_ip} ${aws_vpn_connection.tgw_vpn.tunnel2_address} : PSK "${aws_vpn_connection.tgw_vpn.tunnel2_preshared_key}"
    INNEREOF

    chmod 600 /etc/ipsec.d/aws.secrets
    systemctl enable ipsec
    systemctl restart ipsec

    sed -i 's/bgpd=no/bgpd=yes/' /etc/frr/daemons
    systemctl enable frr

    cat > /etc/frr/frr.conf << 'INNEREOF'
    frr defaults traditional
    log syslog informational
    
    router bgp 65000
      no bgp ebgp-requires-policy
      neighbor ${aws_vpn_connection.tgw_vpn.tunnel1_vgw_inside_address} remote-as ${aws_vpn_connection.tgw_vpn.tunnel1_bgp_asn}
      neighbor ${aws_vpn_connection.tgw_vpn.tunnel2_vgw_inside_address} remote-as ${aws_vpn_connection.tgw_vpn.tunnel2_bgp_asn}
      
      address-family ipv4 unicast
        network 172.16.0.0/16
      exit-address-family
    INNEREOF

    systemctl restart frr
  EOF

  tags = { Name = "On-Premises Customer Gateway" }
}

# ------------------------------------------------------
# Appliance & Branch 1 VPCs
# ------------------------------------------------------
resource "aws_vpc" "appliance_vpc" {
  cidr_block           = "10.5.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "Appliance-VPC" }
}

resource "aws_vpc" "branch1_vpc" {
  cidr_block           = "172.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "Branch1-VPC" }
}

resource "aws_internet_gateway" "appliance_igw" {
  vpc_id = aws_vpc.appliance_vpc.id
  tags   = { Name = "Appliance-IGW" }
}

resource "aws_internet_gateway" "branch1_igw" {
  vpc_id = aws_vpc.branch1_vpc.id
  tags   = { Name = "Branch1-IGW" }
}

resource "aws_subnet" "appliance_public_subnet" {
  vpc_id                  = aws_vpc.appliance_vpc.id
  cidr_block              = "10.5.0.0/28"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "Appliance-Public-Subnet" }
}

resource "aws_subnet" "appliance_tgw_subnet" {
  vpc_id                  = aws_vpc.appliance_vpc.id
  cidr_block              = "10.5.5.0/28"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags                    = { Name = "Appliance-TGW-Subnet" }
}

resource "aws_subnet" "branch1_public_subnet" {
  vpc_id                  = aws_vpc.branch1_vpc.id
  cidr_block              = "172.20.0.0/28"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "Branch1-Public-Subnet" }
}

resource "aws_subnet" "branch1_subnet1" {
  vpc_id                  = aws_vpc.branch1_vpc.id
  cidr_block              = "172.20.16.0/20"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false
  tags                    = { Name = "Branch1-local-Subnet1" }
}

resource "aws_subnet" "branch1_subnet2" {
  vpc_id                  = aws_vpc.branch1_vpc.id
  cidr_block              = "172.20.32.0/20"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false
  tags                    = { Name = "Branch1-local-Subnet2" }
}

resource "aws_eip" "branch1_nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "branch1_natgw" {
  allocation_id = aws_eip.branch1_nat_eip.id
  subnet_id     = aws_subnet.branch1_public_subnet.id
  tags          = { Name = "Branch1 NATGW" }
  depends_on    = [aws_internet_gateway.branch1_igw]
}

resource "aws_vpc_peering_connection" "sdwan_peering" {
  vpc_id      = aws_vpc.appliance_vpc.id
  peer_vpc_id = aws_vpc.branch1_vpc.id
  auto_accept = true
  tags        = { Name = "SDWAN-VPC-Peering" }
}

# Route Tables for Appliance VPC
resource "aws_route_table" "appliance_rt" {
  vpc_id = aws_vpc.appliance_vpc.id
  tags   = { Name = "Appliance-RT" }
}

resource "aws_route" "appliance_default_route" {
  route_table_id         = aws_route_table.appliance_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.appliance_igw.id
}

resource "aws_route" "appliance_peering_route" {
  route_table_id            = aws_route_table.appliance_rt.id
  destination_cidr_block    = "172.20.16.5/32"
  vpc_peering_connection_id = aws_vpc_peering_connection.sdwan_peering.id
}

resource "aws_route_table_association" "appliance_public_assoc" {
  subnet_id      = aws_subnet.appliance_public_subnet.id
  route_table_id = aws_route_table.appliance_rt.id
}

# Route Tables for Branch 1 VPC
resource "aws_route_table" "branch1_public_rt" {
  vpc_id = aws_vpc.branch1_vpc.id
  tags   = { Name = "Branch1-Public-RT" }
}

resource "aws_route" "branch1_default_route" {
  route_table_id         = aws_route_table.branch1_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.branch1_igw.id
}

resource "aws_route_table_association" "branch1_public_assoc" {
  subnet_id      = aws_subnet.branch1_public_subnet.id
  route_table_id = aws_route_table.branch1_public_rt.id
}

resource "aws_route_table" "branch1_private_rt" {
  vpc_id = aws_vpc.branch1_vpc.id
  tags   = { Name = "Branch1-Private-RT" }
}

resource "aws_route" "branch1_peering_route" {
  route_table_id            = aws_route_table.branch1_private_rt.id
  destination_cidr_block    = "10.5.0.6/32"
  vpc_peering_connection_id = aws_vpc_peering_connection.sdwan_peering.id
}

resource "aws_route_table_association" "branch1_private_assoc" {
  subnet_id      = aws_subnet.branch1_subnet1.id
  route_table_id = aws_route_table.branch1_private_rt.id
}

resource "aws_route_table" "branch1_workload_rt" {
  vpc_id = aws_vpc.branch1_vpc.id
  tags   = { Name = "Branch1-Workload-RT" }
}

resource "aws_route" "branch1_workload_default" {
  route_table_id         = aws_route_table.branch1_workload_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.branch1_natgw.id
}

resource "aws_route" "branch1_workload_to_aws" {
  route_table_id         = aws_route_table.branch1_workload_rt.id
  destination_cidr_block = "10.0.0.0/8"
  network_interface_id   = aws_network_interface.router2_eni1.id
}

resource "aws_route" "branch1_workload_to_on_prem" {
  route_table_id         = aws_route_table.branch1_workload_rt.id
  destination_cidr_block = "172.16.0.0/16"
  network_interface_id   = aws_network_interface.router2_eni1.id
}

resource "aws_route_table_association" "branch1_private_assoc2" {
  subnet_id      = aws_subnet.branch1_subnet2.id
  route_table_id = aws_route_table.branch1_workload_rt.id
}

# Security Groups for Routers & Workload
resource "aws_security_group" "router1_sg" {
  name        = "Router 1 SG"
  description = "Security group for Router 1"
  vpc_id      = aws_vpc.appliance_vpc.id

  ingress {
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "47"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["172.20.16.5/32", "10.10.0.1/32", "10.10.0.2/32"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "router2_sg" {
  name        = "Router 2 SG"
  description = "Security group for Router 2"
  vpc_id      = aws_vpc.branch1_vpc.id

  ingress {
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "47"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["10.5.0.6/32"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "branch1_workload_sg" {
  name        = "Branch1 Workload SG"
  description = "Allow ICMP for ping testing"
  vpc_id      = aws_vpc.branch1_vpc.id

  ingress {
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Network Interfaces & Elastic IPs
resource "aws_network_interface" "router1_eni0" {
  subnet_id         = aws_subnet.appliance_public_subnet.id
  private_ips       = ["10.5.0.5"]
  security_groups   = [aws_security_group.router1_sg.id]
  source_dest_check = false
  tags              = { Name = "Router1-ENI0" }
}

resource "aws_network_interface" "router1_eni1" {
  subnet_id         = aws_subnet.appliance_public_subnet.id
  private_ips       = ["10.5.0.6"]
  security_groups   = [aws_security_group.router1_sg.id]
  source_dest_check = false
  tags              = { Name = "Router1-ENI1" }
}

resource "aws_network_interface" "router2_eni0" {
  subnet_id         = aws_subnet.branch1_public_subnet.id
  private_ips       = ["172.20.0.5"]
  security_groups   = [aws_security_group.router2_sg.id]
  source_dest_check = false
  tags              = { Name = "Router2-ENI0" }
}

resource "aws_network_interface" "router2_eni1" {
  subnet_id         = aws_subnet.branch1_subnet1.id
  private_ips       = ["172.20.16.5"]
  security_groups   = [aws_security_group.router2_sg.id]
  source_dest_check = false
  tags              = { Name = "Router2-ENI1" }
}

resource "aws_eip" "router1_eip" {
  domain            = "vpc"
  network_interface = aws_network_interface.router1_eni0.id
  depends_on        = [aws_internet_gateway.appliance_igw]
}

resource "aws_eip" "router2_eip" {
  domain            = "vpc"
  network_interface = aws_network_interface.router2_eni0.id
  depends_on        = [aws_internet_gateway.branch1_igw]
}

resource "aws_network_interface_attachment" "router1_eni1_attach" {
  instance_id          = aws_instance.edge_router1.id
  network_interface_id = aws_network_interface.router1_eni1.id
  device_index         = 1
}

resource "aws_network_interface_attachment" "router2_eni1_attach" {
  instance_id          = aws_instance.edge_router2.id
  network_interface_id = aws_network_interface.router2_eni1.id
  device_index         = 1
}

# Transit Gateway Connect & Peering
resource "aws_ec2_transit_gateway_vpc_attachment" "appliance_tgw_attach" {
  subnet_ids         = [aws_subnet.appliance_tgw_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.appliance_vpc.id
  tags               = { Name = "Appliance-VPC-Attachment" }
}

resource "aws_ec2_transit_gateway_connect" "appliance_connect" {
  transport_attachment_id = aws_ec2_transit_gateway_vpc_attachment.appliance_tgw_attach.id
  transit_gateway_id      = aws_ec2_transit_gateway.tgw.id
  tags                    = { Name = "TGWConnect-Appliance" }
}

resource "aws_ec2_transit_gateway_connect_peer" "tunnel1" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.appliance_connect.id
  peer_address                  = "10.5.0.6"
  transit_gateway_address       = "10.10.0.1"
  inside_cidr_blocks            = ["169.254.255.0/29"]
  bgp_asn                       = 65500
  tags                          = { Name = "GRE1-tunnel" }
}

resource "aws_ec2_transit_gateway_connect_peer" "tunnel2" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_connect.appliance_connect.id
  peer_address                  = "10.5.0.6"
  transit_gateway_address       = "10.10.0.2"
  inside_cidr_blocks            = ["169.254.255.8/29"]
  bgp_asn                       = 65500
  tags                          = { Name = "GRE2-tunnel" }
}

resource "aws_route" "appliance_tgw_gre_route" {
  route_table_id         = aws_route_table.appliance_rt.id
  destination_cidr_block = "10.10.0.0/24"
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.appliance_tgw_attach]
}

locals {
  tunnel1_bgp_addresses = sort(tolist(
    aws_ec2_transit_gateway_connect_peer.tunnel1.bgp_transit_gateway_addresses
  ))

  tunnel2_bgp_addresses = sort(tolist(
    aws_ec2_transit_gateway_connect_peer.tunnel2.bgp_transit_gateway_addresses
  ))
}

# ------------------------------------------------------
# Routers & Branch Workload Instances
# ------------------------------------------------------
resource "aws_instance" "edge_router1" {
  instance_type        = "t3.small"
  ami                  = data.aws_ssm_parameter.ubuntu_ami.value
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  depends_on = [aws_eip.router1_eip]

  primary_network_interface {
    network_interface_id = aws_network_interface.router1_eni0.id
  }

  tags = { Name = "Third-Party Appliance" }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    while ! ping -c 1 -W 1 8.8.8.8; do
      echo "Waiting for internet connection..."
      sleep 5
    done

    export DEBIAN_FRONTEND=noninteractive
    apt-mark hold linux-aws linux-image-aws linux-headers-aws || true

    echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.conf.default.rp_filter = 0" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.conf.all.rp_filter = 0" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p

    apt update && apt upgrade -y
    apt install -y frr frr-pythontools traceroute tcpdump

    while ! ip link show ens6 > /dev/null 2>&1; do
      echo "Waiting for secondary network interface (ens6) to be attached by AWS..."
      sleep 2
    done

    cat > /etc/netplan/99-ens6.yaml << 'INNEREOF'
    network:
      version: 2
      ethernets:
        ens6:
          dhcp4: true
          dhcp4-overrides:
            use-routes: false
    INNEREOF
    netplan apply
    sleep 5

    ip tunnel add gre10 mode gre remote 172.20.16.5 local 10.5.0.6 ttl 255
    ip link set gre10 up
    ip addr add 192.168.255.1/30 dev gre10
    sudo ip route add 172.20.16.5 via 10.5.0.1 dev ens6

    ip tunnel add gre1 mode gre local 10.5.0.6 remote ${aws_ec2_transit_gateway_connect_peer.tunnel1.transit_gateway_address} ttl 255
    ip link set gre1 up
    ip addr add ${aws_ec2_transit_gateway_connect_peer.tunnel1.bgp_peer_address}/29 dev gre1
    ip route replace ${aws_ec2_transit_gateway_connect_peer.tunnel1.transit_gateway_address}/32 via 10.5.0.1 dev ens6 src 10.5.0.6

    ip tunnel add gre2 mode gre local 10.5.0.6 remote ${aws_ec2_transit_gateway_connect_peer.tunnel2.transit_gateway_address} ttl 255
    ip link set gre2 up
    ip addr add ${aws_ec2_transit_gateway_connect_peer.tunnel2.bgp_peer_address}/29 dev gre2
    ip route replace ${aws_ec2_transit_gateway_connect_peer.tunnel2.transit_gateway_address}/32 via 10.5.0.1 dev ens6 src 10.5.0.6

    hostnamectl set-hostname edge-router1
    echo "hostname edge-router1" > /etc/frr/vtysh.conf
    sed -i 's/bgpd=no/bgpd=yes/' /etc/frr/daemons
    systemctl enable frr

    cat <<INNEREOF > /etc/frr/frr.conf
    frr defaults traditional
    hostname edge-router1
    log syslog informational
    service integrated-vtysh-config

    route-map ALLOW_ALL permit 10

    router bgp 65500
        neighbor 192.168.255.2 remote-as 65501
        neighbor 192.168.255.2 update-source gre10
        neighbor 192.168.255.2 soft-reconfiguration inbound

        neighbor ${local.tunnel1_bgp_addresses[0]} remote-as 64512
        neighbor ${local.tunnel1_bgp_addresses[0]} update-source gre1
        neighbor ${local.tunnel1_bgp_addresses[0]} ebgp-multihop 2
        neighbor ${local.tunnel1_bgp_addresses[0]} soft-reconfiguration inbound

        neighbor ${local.tunnel1_bgp_addresses[1]} remote-as 64512
        neighbor ${local.tunnel1_bgp_addresses[1]} update-source gre1
        neighbor ${local.tunnel1_bgp_addresses[1]} ebgp-multihop 2
        neighbor ${local.tunnel1_bgp_addresses[1]} soft-reconfiguration inbound

        neighbor ${local.tunnel2_bgp_addresses[0]} remote-as 64512
        neighbor ${local.tunnel2_bgp_addresses[0]} update-source gre2
        neighbor ${local.tunnel2_bgp_addresses[0]} ebgp-multihop 2
        neighbor ${local.tunnel2_bgp_addresses[0]} soft-reconfiguration inbound

        neighbor ${local.tunnel2_bgp_addresses[1]} remote-as 64512
        neighbor ${local.tunnel2_bgp_addresses[1]} update-source gre2
        neighbor ${local.tunnel2_bgp_addresses[1]} ebgp-multihop 2
        neighbor ${local.tunnel2_bgp_addresses[1]} soft-reconfiguration inbound

        address-family ipv4 unicast
            neighbor 192.168.255.2 route-map ALLOW_ALL out
            neighbor 192.168.255.2 route-map ALLOW_ALL in
            
            neighbor ${local.tunnel1_bgp_addresses[0]} route-map ALLOW_ALL out
            neighbor ${local.tunnel1_bgp_addresses[0]} route-map ALLOW_ALL in
            neighbor ${local.tunnel1_bgp_addresses[1]} route-map ALLOW_ALL out
            neighbor ${local.tunnel1_bgp_addresses[1]} route-map ALLOW_ALL in
            
            neighbor ${local.tunnel2_bgp_addresses[0]} route-map ALLOW_ALL out
            neighbor ${local.tunnel2_bgp_addresses[0]} route-map ALLOW_ALL in
            neighbor ${local.tunnel2_bgp_addresses[1]} route-map ALLOW_ALL out
            neighbor ${local.tunnel2_bgp_addresses[1]} route-map ALLOW_ALL in
        exit-address-family
    INNEREOF

    systemctl restart frr
  EOF
}

resource "aws_instance" "edge_router2" {
  instance_type        = "t3.small"
  ami                  = data.aws_ssm_parameter.ubuntu_ami.value
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  depends_on = [aws_eip.router2_eip]

  primary_network_interface {
    network_interface_id = aws_network_interface.router2_eni0.id
  }

  tags = { Name = "Branch1 Router" }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    while ! ping -c 1 -W 1 8.8.8.8; do
      echo "Waiting for internet connection..."
      sleep 5
    done

    export DEBIAN_FRONTEND=noninteractive
    apt-mark hold linux-aws linux-image-aws linux-headers-aws || true

    echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.conf.default.rp_filter = 0" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.conf.all.rp_filter = 0" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p

    apt update && apt upgrade -y
    apt install -y frr frr-pythontools traceroute tcpdump

    while ! ip link show ens6 > /dev/null 2>&1; do
      echo "Waiting for secondary network interface (ens6) to be attached by AWS..."
      sleep 2
    done

    cat > /etc/netplan/99-ens6.yaml << 'INNEREOF'
    network:
      version: 2
      ethernets:
        ens6:
          dhcp4: true
          dhcp4-overrides:
            use-routes: false
    INNEREOF
    netplan apply
    sleep 5

    ip tunnel add gre10 mode gre remote 10.5.0.6 local 172.20.16.5 ttl 255
    ip link set gre10 up
    ip addr add 192.168.255.2/30 dev gre10

    sudo ip route add 10.5.0.6 via 172.20.16.1 dev ens6
    sudo ip route add 172.20.32.0/20 via 172.20.16.1 dev ens6

    hostnamectl set-hostname edge-router2
    echo "hostname edge-router2" > /etc/frr/vtysh.conf

    sed -i 's/bgpd=no/bgpd=yes/' /etc/frr/daemons
    systemctl enable frr

    cat <<INNEREOF > /etc/frr/frr.conf
    frr defaults traditional
    hostname edge-router2
    log syslog informational
    service integrated-vtysh-config

    route-map ALLOW_ALL permit 10

    router bgp 65501
        neighbor 192.168.255.1 remote-as 65500
        neighbor 192.168.255.1 update-source gre10
        neighbor 192.168.255.1 soft-reconfiguration inbound
        address-family ipv4 unicast
            network 172.20.0.0/28
            network 172.20.16.0/20
            network 172.20.32.0/20
            redistribute connected
            neighbor 192.168.255.1 route-map ALLOW_ALL out
            neighbor 192.168.255.1 route-map ALLOW_ALL in
        exit-address-family
    INNEREOF

    ip rule add from 172.20.37.213 lookup 100
    ip route add default via 192.168.255.1 dev gre10 table 100
    systemctl restart frr
  EOF
}

resource "aws_instance" "branch1_workload" {
  ami           = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.branch1_subnet2.id
  private_ip    = "172.20.37.213"

  vpc_security_group_ids = [aws_security_group.branch1_workload_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  tags = { Name = "Branch1-Test-Workload" }
}
