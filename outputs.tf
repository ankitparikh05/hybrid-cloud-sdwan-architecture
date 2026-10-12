# Spoke VPC Outputs (retrieved from module)
output "vpc_a_id" {
  description = "The Created VPC A"
  value       = module.vpc_a.vpc_id
}

output "vpc_a_public_server_public_ip" {
  value = module.vpc_a.public_server_ip
}

output "vpc_a_public_server_private_ip" {
  value = "10.0.2.100"
}

output "vpc_a_private_server_ip" {
  value = module.vpc_a.private_server_ip
}

output "vpc_b_id" {
  value = module.vpc_b.vpc_id
}

output "vpc_b_server_ip" {
  value = module.vpc_b.private_server_ip
}

output "vpc_c_id" {
  value = module.vpc_c.vpc_id
}

output "vpc_c_server_ip" {
  value = module.vpc_c.private_server_ip
}

# On-Premises Outputs
output "on_prem_vpc" {
  value = aws_vpc.on_prem_vpc.id
}

output "on_prem_vpc_cidr" {
  value = aws_vpc.on_prem_vpc.cidr_block
}

output "on_prem_public_subnet" {
  value = aws_subnet.on_prem_public_subnet.id
}

output "on_prem_private_subnet" {
  value = aws_subnet.on_prem_private_subnet.id
}

output "on_prem_cgw_security_group" {
  value = aws_security_group.on_prem_cgw_sg.id
}

output "public_ip" {
  value = aws_eip.on_prem_cgw_eip.public_ip
}

output "on_prem_app_server_private_ip" {
  value = aws_instance.on_prem_app_server.private_ip
}

output "on_prem_dns_server_private_ip" {
  value = aws_instance.on_prem_dns_server.private_ip
}

output "vpn_tunnel1_cgw_inside_address" {
  value = aws_vpn_connection.tgw_vpn.tunnel1_cgw_inside_address
}

output "vpn_tunnel1_vgw_inside_address" {
  value = aws_vpn_connection.tgw_vpn.tunnel1_vgw_inside_address
}

output "vpn_tunnel1_bgp_asn" {
  value = aws_vpn_connection.tgw_vpn.tunnel1_bgp_asn
}

output "vpn_tunnel2_cgw_inside_address" {
  value = aws_vpn_connection.tgw_vpn.tunnel2_cgw_inside_address
}

output "vpn_tunnel2_vgw_inside_address" {
  value = aws_vpn_connection.tgw_vpn.tunnel2_vgw_inside_address
}

output "vpn_tunnel2_bgp_asn" {
  value = aws_vpn_connection.tgw_vpn.tunnel2_bgp_asn
}

# SD-WAN, Appliance & Branch Outputs
output "appliance_vpc_id" {
  description = "VPC ID of Appliance VPC"
  value       = aws_vpc.appliance_vpc.id
}

output "branch1_vpc_id" {
  description = "VPC ID of Router2 VPC"
  value       = aws_vpc.branch1_vpc.id
}

output "vpc_peering_connection_id" {
  description = "Peering Connection ID"
  value       = aws_vpc_peering_connection.sdwan_peering.id
}

output "router1_public_ip" {
  value = aws_eip.router1_eip.public_ip
}

output "router2_public_ip" {
  value = aws_eip.router2_eip.public_ip
}

output "branch1_workload_private_ip" {
  value = aws_instance.branch1_workload.private_ip
}
