Day 2 Operations & Incident Response Runbook

1. Infrastructure Management & Scaling (How-To Guides)
This section outlines the standard operating procedures for scaling the hybrid network architecture without causing state drift or downtime.

1.1 Adding a New AWS VPC (Spoke)
To deploy a new spoke VPC (e.g., VPC D) into the Transit Gateway (TGW) hub, leverage the existing Terraform module:
• Open main.tf and append a new module block using source = "./modules/spoke_vpc".
• Assign a unique CIDR block (e.g., 10.3.0.0/16) to avoid overlapping with VPC A, B, or C.
• Update the for_each loop array inside the TGW route injection blocks (e.g., aws_route.vpc_a_private_tgw) to include the new VPC's CIDR block so existing VPCs know how to route to it.
• Apply the changes via terraform apply. The module will automatically provision the VPC, Subnets, Route Tables, NAT Gateways, and EC2 instances.

1.2 Adding a New Branch Office
To simulate or integrate a new SD-WAN branch office:
• Replicate the branch1_vpc resource block in main.tf, assigning a new isolated CIDR (e.g., 172.21.0.0/16).
• Provision a new SD-WAN router instance (e.g., edge_router3) and attach a secondary ENI for the GRE tunnel.
• Assign a new unique private Autonomous System Number (ASN) (e.g., 65502) in the user data FRRouting configuration to establish a discrete BGP peering session with the central appliance.

1.3 Terraform State Management
Because the state is stored remotely with native locking, team members must adhere to strict state management rules:
• Authentication: Ensure AWS CLI credentials are valid and assume the correct IAM permissions before executing Terraform.
• Locking: If a deployment pipeline crashes or your local machine loses power mid-apply, the S3 state lockfile may remain active. Run terraform force-unlock <LOCK_ID> only after verifying no other pipeline or user is actively running an apply.
• State Rollback: If the terraform.tfstate becomes corrupted, navigate to the ankit-networking-tfstate-bucket-2026 S3 bucket, download the previous working version via S3 Object Versioning, and push it back as the primary state.

2. Operational Monitoring & Health Checks
Use these steps to validate the health of the custom routing appliances (Libreswan and FRR) and DNS endpoints.

2.1 BGP Routing Health (FRRouting)
BGP is responsible for dynamic route propagation between AWS, the SD-WAN appliance, and the on-premises network.
• SSH into the Customer Gateway (on_prem_cgw) or SD-WAN Routers (edge_router1, edge_router2).
• Run sudo vtysh -c "show ip bgp summary" to verify that BGP peers are in the Established state and receiving prefixes.
• Run sudo vtysh -c "show ip route bgp" to view the actual routing table injected by BGP to ensure AWS TGW routes (e.g., 10.0.0.0/8) are present.

2.2 IPsec VPN Tunnel Status (Libreswan)
The on-premises Customer Gateway utilizes dual IPsec tunnels for high availability.
• SSH into on_prem_cgw.
• Run sudo ipsec trafficstatus to verify that both Tunnel1 and Tunnel2 are active and encrypting/decrypting traffic.
• Run sudo ipsec status for deeper cryptographic details if a tunnel shows as down.

2.3 Hybrid DNS Resolution Validation
The Route 53 Outbound Endpoint relies on the on-premises BIND server to resolve .corp domains.
• Access a private instance in VPC A, B, or C via AWS Systems Manager (SSM) Session Manager.
• Run dig @172.16.1.200 myapp.example.corp to test direct resolution against the BIND server.
• Run nslookup myapp.example.corp without specifying a server to verify that the AWS VPC DNS resolver is correctly forwarding requests through the Route 53 Outbound Endpoint rule.

3. Troubleshooting Runbooks & Maintenance
Pre-defined response strategies for common network incidents and routine patching.

3.1 GRE Tunnel / Transit Gateway Connect Drops
If SD-WAN workloads lose connectivity to AWS resources, the GRE tunnels over the TGW Connect attachment may be failing.
• SSH into edge_router1.
• Run tcpdump -npi ens6 proto 47 to monitor raw GRE encapsulated packets (Protocol 47) entering and leaving the external interface.
• Run telnet <TGW-BGP-PEER-IP> 179 to test TCP connectivity to the Transit Gateway's BGP port. If this fails, verify the Security Group attached to router1_eni1 allows inbound traffic from the TGW Connect inside CIDR block.
• Verify that the MTU of the GRE tunnel is smaller than the external interface to prevent BGP packet fragmentation.

3.2 Asymmetric Routing Resolution
Because there are multiple VPN tunnels and BGP paths, traffic might enter through Tunnel 1 but attempt to return via Tunnel 2, causing stateful firewalls or security groups to drop the packets.
• Run traceroute -n <TARGET_IP> from the on-premises App Server to an AWS Spoke VPC instance.
• Run traceroute -n <TARGET_IP> from the AWS Spoke VPC instance back to the App Server.
• If the paths differ, log into the on_prem_cgw and adjust the BGP MED (Multi-Exit Discriminator) or AS-PATH prepending in the FRR route-map to force symmetrical traffic flows.

3.3 AMI and Package Maintenance (Patching)
Routinely patching the Linux routers is critical for security but must be handled carefully to avoid network downtime.
• Infrastructure Level (Terraform): The data.tf file is configured to pull the latest_ami from AWS Systems Manager. Running terraform apply after an upstream AWS patch will completely destroy and recreate the EC2 instances. You must schedule downtime for this, as routing will fail while user_data rebuilds the tunnels.
• OS Level (In-Place Patching): To patch without destroying the instances, SSH into the Ubuntu SD-WAN routers and run sudo apt update && sudo apt upgrade -y. For the Amazon Linux 2023 Customer Gateway, run sudo dnf update -y.
• Persistence: Because network configurations (ip tunnel add, ip route add) are executed via user_data on initial boot, rebooting an instance via the AWS Console will wipe the GRE tunnels unless they are manually written to /etc/network/interfaces or netplan. If an instance reboots, you may need to manually re-run the tunneling commands from the user_data script.

3.4 Hybrid DNS Resolution Failures
If an AWS instance fails to resolve myapp.example.corp, verify the components in the resolution path:
• First verify the endpoint's security configuration. Ensure aws_security_group.r53_outbound_sg is correctly applied to the Outbound Endpoint and explicitly allows outbound UDP and TCP Port 53 traffic to the on-premises 172.16.0.0/16 CIDR block.
• If the security group is correct, SSH into the on-premises DNS Server (172.16.1.200) and inspect the BIND debug logs located at /var/named/data/named.run (as configured in your user_data script) to verify if the Route 53 queries are successfully traversing the VPN and reaching the server.


