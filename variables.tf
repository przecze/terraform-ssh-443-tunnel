variable "aws_region" {
  description = "AWS region to deploy in"
  type        = string
  default     = "us-east-1"
}

variable "security_group_name" {
  description = "Name of your existing security group (must allow 22 and 443)"
  type        = string
}

variable "key_name" {
  description = "Name of your existing EC2 key pair"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (t3.nano is cheapest at ~$0.005/hr)"
  type        = string
  default     = "t3.nano"
}

variable "auto_shutdown_hours" {
  description = "Auto-terminate instance after this many hours (safety net)"
  type        = number
  default     = 4
}

