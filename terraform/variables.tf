
variable "region" {
  type        = string
  description = "The AWS region to deploy to"
  default     = "eu-west-1"
}

variable "default_tag" {
  type        = string
  description = "A default tag to add to everything"
  default     = "terraform-project-com"
}

variable "domain_name" {
  type        = string
  description = "The domain name for the project"
  default     = "terraform-project.com"
}



variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for the private subnets"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for the public subnets"
  type        = list(string)
}

variable "instance_type" {
  description = "The EC2 instance type"
  type        = string
  default     = "t3.large"
}

variable "rds_instance_type" {
  description = "The RDS instance type"
  type        = string
  default     = "db.t4g.small"
}
