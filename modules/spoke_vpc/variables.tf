variable "vpc_name" { 
    type = string  
}
variable "cidr_block" { 
    type = string 
    }
variable "az_a" {
     type = string 
     }
variable "az_b" { 
    type = string 
    }

variable "subnet_cidrs" {
  type = object({
    pub_1 = string, pub_2 = string
    priv_1 = string, priv_2 = string
    tgw_1 = string, tgw_2 = string
  })
}

variable "server_ip" { 
type = string 
}
variable "ami_id" { 
    type = string 
    }
variable "instance_profile_name" {
     type = string 
     }

variable "create_public_server" { 
  type = bool 
  default = false 
}

variable "public_server_ip" { 
  type = string 
  default = "" 
}
