variable "name" {
  type        = string
  description = "NAT instance name (will be used as prefix in all resource names.)"
}

variable "vpc_id" {
  type        = string
  description = "ID of VPC where NAT instance should be deployed."
}

variable "sshsg" {
  type        = string
  description = "Security group permitted to SSH int NAT instances."
}

variable "azs" {
  type        = list
  description = "List of availability zones where subnets are created."
}

variable "public_subnets" {
  type        = list
  description = "List of public subnets where to place NAT isntances."
}

variable "private_subnets" {
  type        = list
  description = "List of private subnets which should be masked."
}

variable "private_route_tables" {
  type        = list
  description = "List of private route tables."
}

variable "private_subnets_cidr_blocks" {
  type        = list
  description = "List of private subnet CIDRs."
}

variable "instance_types_ondemand" {
  default     = "t3.nano"
  description = "instance_types_ondemand parameter for Spotinst Elastigroup."
}

variable "instance_types_spot" {
  default     = ["t3.nano", "t3a.nano", "t3.micro", "t3a.micro", "t2.micro"]
  description = "instance_types_spot parameter for Spotinst Elastigroup."
}

variable "instance_types_preferred_spot" {
  default     = ["t3.nano", "t3a.nano"]
  description = "instance_types_preferred_spot parameter for Spotinst Elastigroup."
}
