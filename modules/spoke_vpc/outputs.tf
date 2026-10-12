output "vpc_id" { 
    value = aws_vpc.this.id
    }
output "public_rt_id" { 
    value = aws_route_table.public_rt.id 
    }
output "private_rt_id" { 
    value = aws_route_table.private_rt.id 
    }
output "tgw_subnet_ids" {
    value = [aws_subnet.tgw_1.id, aws_subnet.tgw_2.id] 
    }

output "private_server_ip" { 
    value = aws_instance.private_server.private_ip 
    }
# Only output the public IP if the public server was actually created
output "public_server_ip" { 
    value = var.create_public_server ? aws_instance.public_server[0].public_ip : null 
    }

output "private_subnet_1_id" { 
    value = aws_subnet.priv_1.id 
    }
output "private_subnet_2_id" { 
    value = aws_subnet.priv_2.id 
    }
    