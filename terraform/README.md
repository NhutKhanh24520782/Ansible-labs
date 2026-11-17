# Terraform Infrastructure as Code (IaC) - AWS MongoDB Replica Set Cluster (5 Nodes)

Mã nguồn Terraform này tự động khởi tạo toàn bộ hạ tầng mạng bảo mật và 5 máy chủ ảo EC2 trên AWS (Region `ap-southeast-1` Singapore) để phục vụ việc cấu hình **MongoDB 7.0 Replica Set (`rs0`)** bằng Ansible.

---

## 🏛️ 1. Kiến trúc mạng & Luồng kết nối (Network Architecture)

```text
                                Internet
                                   │
               ┌───────────────────┴───────────────────┐
               │         Internet Gateway (IGW)         │
               └───────────────────┬───────────────────┘
                                   │
┌──────────────────────────────────▼────────────────────────────────────────┐
│ VPC: 10.0.0.0/16                                                          │
│                                                                           │
│   ┌───────────────────────────────────────────────────────────────────┐   │
│   │ PUBLIC SUBNET: 10.0.0.0/24                                        │   │
│   │                                                                   │   │
│   │   [ Bastion Host (t3.micro) ] ◄────── SSH (Port 22 từ Admin IP)  │   │
│   │        Public IP: Gán tự động                                     │   │
│   │                                                                   │   │
│   │   [ NAT Gateway ] ───────────────────► Tải apt packages ra ngoài  │   │
│   └──────────────────────────┬────────────────────────────────────────┘   │
│                              │                                            │
│   ┌──────────────────────────▼────────────────────────────────────────┐   │
│   │ PRIVATE SUBNET: 10.0.1.0/24 (Không có Public IP)                  │   │
│   │                                                                   │   │
│   │   ┌───────────────────────────────────────────────────────────┐   │   │
│   │   │ MongoDB Security Group (Port 27017 self, Port 22 Bastion) │   │   │
│   │   │                                                           │   │   │
│   │   │  • mongo-node-1: 10.0.1.11 (t3.small)                     │   │   │
│   │   │  • mongo-node-2: 10.0.1.12 (t3.small)                     │   │   │
│   │   │  • mongo-node-3: 10.0.1.13 (t3.small)                     │   │   │
│   │   │  • mongo-node-4: 10.0.1.14 (t3.small)                     │   │   │
│   │   │  • mongo-node-5: 10.0.1.15 (t3.small)                     │   │   │
│   │   └───────────────────────────────────────────────────────────┘   │   │
│   └───────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────┘
```

### Các quyết định thiết kế (Design Decisions):
1. **Phân vùng mạng cô lập (Defense in Depth):**
   - 5 nodes MongoDB đặt hoàn toàn trong **Private Subnet (`10.0.1.0/24`)**, không gán Public IP, cách ly tuyệt đối khỏi Internet.
   - Chỉ có **Bastion Host** đặt ở Public Subnet để làm điểm nhảy SSH (Jump Host).
2. **Quy tắc Security Group nghiêm ngặt:**
   - **Bastion SG:** Chỉ cho phép SSH port 22 từ biến `allowed_ssh_cidr` (IP cá nhân của bạn), cấm tuyệt đối `0.0.0.0/0`.
   - **MongoDB SG:**
     - SSH port 22: Chỉ nhận kết nối bắt nguồn từ `aws_security_group.bastion.id`.
     - Port 27017: Chỉ mở nội bộ giữa các thành viên của cluster (`self = true`).
3. **NAT Gateway cho APT Outbound:**
   - Bắt buộc cần thiết để các máy chủ Private có thể kết nối ra kho lưu trữ `repo.mongodb.org` để cài đặt MongoDB 7.0 qua Ansible.
4. **Tối ưu chi phí:**
   - Bastion Host dùng `t3.micro`.
   - 5 MongoDB nodes dùng `t3.small` (đáp ứng tốt nhu cầu RAM cho MongoDB WiredTiger engine và replica set).
   - Biến `enable_nat_gateway` cho phép bật/tắt linh hoạt để tiết kiệm ngân sách.

---

## 📁 2. Cấu trúc thư mục dự án

```text
terraform/
├── versions.tf                  # Khai báo phiên bản Terraform (>= 1.6) và providers (AWS, Local)
├── providers.tf                 # Cấu hình AWS provider và default tags
├── variables.tf                 # Khai báo các biến đầu vào (CIDRs, IPs cố định, Instance types)
├── networking.tf                # VPC, Public/Private Subnets, IGW, NAT Gateway, Route Tables
├── security.tf                  # Security Groups cho Bastion và MongoDB Cluster
├── main.tf                      # AMI Ubuntu 22.04, Bastion Host, 5 MongoDB EC2s, Auto Inventory
├── outputs.tf                   # Xuất thông tin IDs, IPs, SSH commands, Ansible Inventory
├── terraform.tfvars.example     # File mẫu cấu hình biến
└── README.md                    # Hướng dẫn chi tiết
```

---

## 🚀 3. Hướng dẫn thực thi từng bước (Step-by-Step Guide)

### Bước 1: Chuẩn bị file biến `terraform.tfvars`
Tạo file `terraform.tfvars` từ file mẫu:
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```
Chỉnh sửa file `terraform.tfvars`:
```hcl
aws_region       = "ap-southeast-1"
allowed_ssh_cidr = "203.0.113.10/32"    # <--- Thay bằng IP của bạn (lấy tại https://checkip.amazonaws.com)
key_name         = "my-aws-keypair"     # <--- Thay bằng tên Key Pair có sẵn trên AWS EC2 Singapore
```

### Bước 2: Khởi tạo Terraform (Init)
Tải providers và cấu hình backend:
```bash
terraform init
```

### Bước 3: Định dạng & Kiểm tra cú pháp (Format & Validate)
```bash
terraform fmt -recursive
terraform validate
```

### Bước 4: Xem trước kế hoạch thay đổi (Plan)
```bash
terraform plan
```
*Kiểm tra số lượng tài nguyên dự kiến tạo: 1 VPC, 2 Subnets, 1 IGW, 1 NAT GW + EIP, 2 Route Tables, 2 Security Groups, 6 EC2 instances (1 Bastion + 5 MongoDB).*

### Bước 5: Triển khai hạ tầng (Apply)
> ⚠️ **Lưu ý:** Chỉ thực hiện khi bạn đã sẵn sàng tạo tài nguyên trên tài khoản AWS của mình.
```bash
terraform apply
# Gõ 'yes' để xác nhận
```

---

## 🔗 4. Kiểm tra kết nối & Tích hợp Ansible

Sau khi `terraform apply` thành công:
1. **Kiểm tra file inventory tự động sinh:**
   Terraform sẽ tự động tạo file `terraform/inventory.ini` chứa đầy đủ cấu hình kết nối qua Bastion ProxyJump:
   ```ini
   [mongodb_nodes]
   mongo-node-1 ansible_host=10.0.1.11 mongo_bind_ip=10.0.1.11 mongo_node_id=0
   mongo-node-2 ansible_host=10.0.1.12 mongo_bind_ip=10.0.1.12 mongo_node_id=1
   mongo-node-3 ansible_host=10.0.1.13 mongo_bind_ip=10.0.1.13 mongo_node_id=2
   mongo-node-4 ansible_host=10.0.1.14 mongo_bind_ip=10.0.1.14 mongo_node_id=3
   mongo-node-5 ansible_host=10.0.1.15 mongo_bind_ip=10.0.1.15 mongo_node_id=4

   [mongodb_nodes:vars]
   ansible_user=ubuntu
   ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -W %h:%p -q ubuntu@<BASTION_PUBLIC_IP>"'
   ```

2. **Kiểm tra kết nối SSH trực tiếp bằng SSH ProxyJump:**
   ```bash
   # SSH trực tiếp vào mongo-node-1 qua Bastion trong 1 dòng lệnh duy nhất:
   ssh -i ~/.ssh/my-aws-keypair.pem -J ubuntu@<BASTION_PUBLIC_IP> ubuntu@10.0.1.11
   ```

3. **Chạy Ansible Playbook đã dựng:**
   Sao chép file inventory sang thư mục ansible và thực thi:
   ```bash
   cp inventory.ini ../ansible/inventory/hosts.ini
   cd ../ansible
   ansible -i inventory/hosts.ini mongodb_nodes -m ping --private-key=~/.ssh/my-aws-keypair.pem
   ansible-playbook -i inventory/hosts.ini site.yml --private-key=~/.ssh/my-aws-keypair.pem
   ```

---

## 🧹 5. Hủy tài nguyên để tránh phát sinh chi phí (Destroy)

Sau khi hoàn thành bài thực hành:
```bash
cd terraform
terraform destroy
# Gõ 'yes' để xác nhận hủy toàn bộ tài nguyên
```
> [!IMPORTANT]
> **NAT Gateway** và **EC2 Instances** tính phí theo giờ chạy. Hãy đảm bảo chạy `terraform destroy` khi hoàn thành bài lab để không phát sinh chi phí ngoài ý muốn!

