
variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "task2"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "vm_size" {
  description = "Linux VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_ip_cidr" {
  description = "Your public IP address with /32"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}