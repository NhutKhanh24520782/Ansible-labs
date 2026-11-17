variable "aws_region" {
  type        = string
  description = "AWS Region triển khai hạ tầng"
  default     = "ap-southeast-1"
}

variable "project_name" {
  type        = string
  description = "Tên dự án dùng cho prefix đặt tên và tagging"
  default     = "nt548"
}

variable "environment" {
  type        = string
  description = "Môi trường triển khai (dev, staging, prod)"
  default     = "dev"
}

variable "vpc_cidr" {
  type        = string
  description = "Dải CIDR của VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "Dải CIDR của Public Subnet (chứa Bastion Host và NAT Gateway)"
  default     = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "Dải CIDR của Private Subnet (chứa 5 MongoDB nodes)"
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  type        = string
  description = "Availability Zone triển khai tài nguyên"
  default     = "ap-southeast-1a"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "Địa chỉ IP quản trị duy nhất được phép SSH vào Bastion Host (dạng x.x.x.x/32)"
}

variable "key_name" {
  type        = string
  description = "Tên AWS Key Pair có sẵn trên EC2 dùng để truy cập SSH"
}

variable "instance_type" {
  type        = string
  description = "Loại EC2 instance cho các MongoDB nodes"
  default     = "t3.small"
}

variable "bastion_instance_type" {
  type        = string
  description = "Loại EC2 instance cho Bastion Host (tiết kiệm chi phí)"
  default     = "t3.micro"
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Tạo NAT Gateway cho Private Subnet ra ngoài Internet tải package APT (tắt để tiết kiệm chi phí khi không cần)"
  default     = true
}

variable "mongodb_nodes" {
  type = map(object({
    node_id    = number
    private_ip = string
  }))
  description = "Danh sách 5 MongoDB nodes với node_id và private IP cố định"
  default = {
    "mongo-node-1" = { node_id = 0, private_ip = "10.0.1.11" }
    "mongo-node-2" = { node_id = 1, private_ip = "10.0.1.12" }
    "mongo-node-3" = { node_id = 2, private_ip = "10.0.1.13" }
    "mongo-node-4" = { node_id = 3, private_ip = "10.0.1.14" }
    "mongo-node-5" = { node_id = 4, private_ip = "10.0.1.15" }
  }
}

