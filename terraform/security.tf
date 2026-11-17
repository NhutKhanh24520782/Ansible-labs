# ==============================================================================
# Security Groups: Bastion Host SG & MongoDB Internal Cluster SG
# ==============================================================================

# 1. Security Group cho Bastion Host (Public Access)
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Security group cho Bastion Host - Chi cho phep SSH tu IP quan tri"
  vpc_id      = aws_vpc.main.id

  # Ingress: SSH port 22 duy nhất từ IP quản trị (không dùng 0.0.0.0/0)
  ingress {
    description = "SSH from authorized management CIDR only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Egress: Toàn bộ ra ngoài để quản trị và cập nhật
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
  }
}

# 2. Security Group cho MongoDB Nodes (Private Internal Only)
resource "aws_security_group" "mongodb" {
  name        = "${var.project_name}-${var.environment}-mongodb-sg"
  description = "Security group cho 5 MongoDB nodes - Giao tiep noi bo va SSH qua Bastion"
  vpc_id      = aws_vpc.main.id

  # Ingress 1: SSH port 22 CHỈ nhận từ Bastion Security Group
  ingress {
    description     = "SSH inbound from Bastion Host only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Ingress 2: MongoDB Port 27017 CHỈ cho phép giao tiếp giữa 5 nodes (self = true)
  ingress {
    description = "MongoDB Replica Set inter-node communication"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    self        = true
  }

  # Ingress 3: ICMP (Ping) nội bộ giữa các node để kiểm tra mạng
  ingress {
    description = "Internal ICMP ping between nodes"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    self        = true
  }

  # Egress: Cho phép kết nối ra ngoài qua NAT Gateway (để tải package MongoDB 7.0)
  egress {
    description = "Allow all outbound traffic via NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-mongodb-sg"
  }
}

