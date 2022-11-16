variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "devops_admin_public_ip" {
  type    = string
  default = "84.109.22.240/32"
}

variable "sg" {
  type    = string
  default = "DEVOPS_ADMIN.id"
}
