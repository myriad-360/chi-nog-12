variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources into"
}

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key ID"
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Access Key"
  sensitive   = true
}

variable "key_name" {
  type        = string
  description = "The name of the existing AWS key pair to use"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type"
}

variable "vpc_name" {
  type        = string
  default     = ""
  description = "Name of the VPC to use. Leave empty to use default VPC"
}

variable "subnet_name" {
  type        = string
  default     = ""
  description = "Name of the subnet to use. Leave empty to use a default subnet in the selected VPC"
}