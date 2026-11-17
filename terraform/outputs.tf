# ==============================================================================
# Terraform Outputs
# ==============================================================================

# 1. Network Outputs
output "vpc_id" {
  description = "ID của Virtual Private Cloud (VPC)"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID của Public Subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID của Private Subnet"
  value       = aws_subnet.private.id
}

# 2. Security Group Outputs
output "bastion_security_group_id" {
  description = "ID của Security Group Bastion Host"
  value       = aws_security_group.bastion.id
}

output "mongodb_security_group_id" {
  description = "ID của Security Group nội bộ 5 MongoDB Nodes"
  value       = aws_security_group.mongodb.id
}

# 3. Bastion Host Outputs
output "bastion_public_ip" {
  description = "Địa chỉ Public IP của Bastion Host dùng để SSH vào quản trị"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID của Bastion Host"
  value       = aws_instance.bastion.id
}

# 4. MongoDB Nodes Outputs
output "mongodb_private_ips" {
  description = "Bản đồ danh sách Private IP cố định của 5 MongoDB nodes"
  value       = { for k, v in aws_instance.mongodb : k => v.private_ip }
}

output "mongodb_instance_ids" {
  description = "Bản đồ Instance ID của 5 MongoDB nodes"
  value       = { for k, v in aws_instance.mongodb : k => v.id }
}

# 5. Lệnh SSH mẫu hỗ trợ kết nối
output "ssh_bastion_command" {
  description = "Lệnh SSH trực tiếp vào Bastion Host"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.bastion.public_ip}"
}

output "ssh_jump_mongo1_command" {
  description = "Lệnh SSH trực tiếp vào mongo-node-1 qua Bastion (ProxyJump)"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem -J ubuntu@${aws_instance.bastion.public_ip} ubuntu@10.0.1.11"
}

# 6. Ansible Inventory Raw Format
output "ansible_inventory_content" {
  description = "Nội dung inventory định dạng INI dùng cho Ansible"
  value       = local_file.ansible_inventory.content
}

