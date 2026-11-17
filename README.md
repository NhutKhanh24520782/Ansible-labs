# NT548 - DevOps Lab: Tự động hóa Hạ tầng AWS & Triển khai MongoDB 7.0 Replica Set

Dự án này cung cấp mã nguồn hoàn chỉnh kết hợp giữa **Terraform (Infrastructure as Code)** và **Ansible (Configuration Management)** để tự động hóa 100% quy trình:
1. **Terraform**: Khởi tạo mạng VPC bảo mật, Bastion Host, NAT Gateway và 5 máy chủ ảo EC2 (Ubuntu 22.04 LTS) với Private IP cố định trên AWS Singapore (`ap-southeast-1`).
2. **Ansible**: Tự động cài đặt MongoDB 7.0 Community Edition, cấu hình service và khởi tạo cụm **Replica Set `rs0`** (1 PRIMARY, 4 SECONDARY) có kiểm tra sức khỏe và tính Idempotent cao.

---

## 📁 1. Cấu trúc thư mục dự án

```text
lab-devops/
├── terraform/                           # Infrastructure as Code (IaC) AWS
│   ├── versions.tf                      # Cấu hình Terraform >= 1.6 & AWS Provider ~> 5.0
│   ├── providers.tf                     # AWS provider và default tags
│   ├── variables.tf                     # Khai báo biến (CIDR, IPs cố định, Instance types)
│   ├── networking.tf                    # VPC, Public/Private Subnets, IGW, NAT Gateway, Routing
│   ├── security.tf                      # Security Groups (Bastion SG và MongoDB Internal SG)
│   ├── main.tf                          # Ubuntu 22.04 AMI, Bastion, 5 MongoDB EC2s, Auto Inventory
│   ├── outputs.tf                       # Xuất IP, ID, lệnh SSH ProxyJump và cấu hình Inventory
│   ├── terraform.tfvars.example         # File biến mẫu
│   └── README.md                        # Hướng dẫn chi tiết cho phần Terraform
│
├── ansible/                             # Configuration Management & MongoDB Cluster Automation
│   ├── ansible.cfg                      # Cấu hình Ansible chuẩn (inventory, roles_path, timeout)
│   ├── site.yml                         # Master Playbook entrypoint
│   ├── inventory/
│   │   ├── hosts.ini                    # Khai báo 5 MongoDB nodes kết nối nội bộ
│   │   └── group_vars/
│   │       └── all.yml                  # Biến toàn cục (port 27017, rs0, repo MongoDB 7.0)
│   ├── playbooks/
│   │   └── deploy-mongodb-cluster.yml   # Playbook điều phối role mongodb
│   ├── roles/
│   │   └── mongodb/
│   │       ├── defaults/main.yml        # Giá trị mặc định
│   │       ├── handlers/main.yml        # Handlers restart / reload mongod
│   │       ├── tasks/
│   │       │   ├── main.yml             # Task chính điều phối
│   │       │   ├── install.yml          # Cài đặt MongoDB 7.0 & Version Pinning
│   │       │   ├── configure.yml        # Cấu hình mongod.conf & enable service
│   │       │   ├── replica_set.yml      # Khởi tạo rs0 (Idempotent)
│   │       │   └── verify.yml           # Kiểm tra Cluster Health (1 PRIMARY & 4 SECONDARY)
│   │       └── templates/
│   │           └── mongod.conf.j2       # Template cấu hình mongod.conf chuẩn MongoDB 7.0
│   └── README.md                        # Hướng dẫn chi tiết cho phần Ansible
│
├── .gitignore                           # Loại trừ tfstate, pem key, secrets và artifacts
├── CONTRIBUTING.md                      # Quy ước nhánh, commit và Pull Request
└── README.md                            # Hướng dẫn tổng thể toàn bộ dự án
```

---

## 🏛️ 2. Sơ đồ kiến trúc hạ tầng & Luồng kết nối

```text
                                Internet
                                   │
               ┌───────────────────┴───────────────────┐
               │         Internet Gateway (IGW)         │
               └───────────────────┬───────────────────┘
                                   │
┌──────────────────────────────────▼────────────────────────────────────────┐
│ VPC: 10.0.0.0/16 (Singapore: ap-southeast-1a)                             │
│                                                                           │
│   ┌───────────────────────────────────────────────────────────────────┐   │
│   │ PUBLIC SUBNET: 10.0.0.0/24                                        │   │
│   │                                                                   │   │
│   │   [ Bastion Host (t3.micro) ] ◄────── SSH (Port 22 từ IP Quản trị)│   │
│   │        Public IP: Gán tự động (Đồng thời là Ansible Control Node) │   │
│   │                                                                   │   │
│   │   [ NAT Gateway + EIP ] ─────────────► Tải apt packages ra ngoài  │   │
│   └──────────────────────────┬────────────────────────────────────────┘   │
│                              │                                            │
│   ┌──────────────────────────▼────────────────────────────────────────┐   │
│   │ PRIVATE SUBNET: 10.0.1.0/24 (Không gắn Public IP)                 │   │
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

---

## 🚀 3. Hướng dẫn chạy toàn bộ quy trình (End-to-End Walkthrough)

### PHẦN 1: Khởi tạo hạ tầng AWS với Terraform

#### Bước 1: Chuẩn bị biến cấu hình
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Mở `terraform.tfvars` và cập nhật 2 giá trị bắt buộc:
1. `allowed_ssh_cidr`: Địa chỉ **Public IP** của máy bạn kèm `/32`.  
   *(Lấy IP thật bằng lệnh `curl -s https://checkip.amazonaws.com`. Tuyệt đối không dùng IP nội bộ `10.x.x.x` hoặc `192.168.x.x`)*.
2. `key_name`: Tên AWS Key Pair có sẵn trên EC2 Console Singapore (ví dụ: `key`).
3. Đặt file private key tương ứng (ví dụ `key.pem`) vào thư mục `terraform/`.

#### Bước 2: Khởi tạo và kiểm tra cú pháp Terraform
```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

#### Bước 3: Triển khai hạ tầng lên AWS
```bash
terraform apply -auto-approve
```
*Sau khi hoàn tất (~2-3 phút), Terraform sẽ xuất ra Public IP của Bastion Host (ví dụ: `13.250.27.77`) và danh sách IP của 5 nodes MongoDB.*

---

### PHẦN 2: Chuyển mã nguồn Ansible lên Bastion Host

Vì Ansible yêu cầu môi trường Linux, giải pháp chuẩn DevOps là sử dụng chính **Bastion Host (Ubuntu)** làm **Ansible Control Node**:

#### Bước 1: Copy thư mục `ansible` và file key lên Bastion
Từ máy tính của bạn (đứng tại thư mục gốc `d:/lab-devops` trong Git Bash):
```bash
# Thay 13.250.27.77 bằng Bastion Public IP của bạn
scp -i terraform/key.pem -r ansible terraform/key.pem ubuntu@13.250.27.77:~/
```

#### Bước 2: SSH đăng nhập vào Bastion Host
```bash
ssh -i terraform/key.pem ubuntu@13.250.27.77
```

---

### PHẦN 3: Triển khai MongoDB Replica Set với Ansible

Khi đã ở trong terminal của Bastion Host (`ubuntu@ip-...:~$`):

#### Bước 1: Cài đặt Ansible trên Bastion (mất ~15 giây)
```bash
sudo apt update && sudo apt install -y ansible
```

#### Bước 2: Cài đặt SSH Key mặc định
```bash
cp ~/key.pem ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
```

#### Bước 3: Di chuyển vào thư mục `ansible` và kiểm tra kết nối tới 5 nodes
```bash
cd ~/ansible
ansible -i inventory/hosts.ini mongodb_nodes -m ping
```
*Kết quả mong đợi: Cả 5 nodes `mongo-node-1` đến `mongo-node-5` đều báo `SUCCESS => "ping": "pong"` màu xanh.*

#### Bước 4: Chạy Playbook triển khai MongoDB 7.0 Replica Set
```bash
ansible-playbook -i inventory/hosts.ini site.yml
```
*Playbook sẽ tự động:*
1. Cài đặt MongoDB 7.0 Community Edition và `mongosh` trên cả 5 nodes.
2. Ghim phiên bản (`dpkg_selections: hold`) chống tự nâng cấp lỗi.
3. Cấu hình `/etc/mongod.conf` chuẩn cho MongoDB 7.0 (`replSetName: rs0`, lắng nghe `0.0.0.0:27017`).
4. Khởi động dịch vụ `mongod`.
5. Tự động khởi tạo Replica Set `rs.initiate()` trên `mongo-node-1` với đủ 5 members.
6. Chờ bầu cử và xác thực sức khỏe cụm đạt **chính xác 1 PRIMARY và 4 SECONDARY**.

---

### PHẦN 4: Kiểm tra trực tiếp trên MongoDB & Xác thực dữ liệu

Ngay từ Bastion Host:

#### 1. SSH vào node PRIMARY (`mongo-node-1`):
```bash
ssh ubuntu@10.0.1.11
```

#### 2. Mở MongoDB Shell:
```bash
mongosh --port 27017
```
*(Dấu nhắc lệnh hiển thị: `rs0 [direct: primary] test>`)*

#### 3. Kiểm tra trạng thái Cluster:
```javascript
rs.status()
```
*Xác nhận: `set: "rs0"`, 1 member có `stateStr: "PRIMARY"` và 4 members có `stateStr: "SECONDARY"`.*

#### 4. Thử ghi dữ liệu trên PRIMARY:
```javascript
use devops_db
db.demo.insertOne({ lab: "MongoDB Replica Set rs0", timestamp: new Date() })
db.demo.find()
```

#### 5. Thoát mongosh và node:
```bash
exit   # thoát mongosh
exit   # thoát mongo-node-1 về Bastion
```

---

### PHẦN 5: ⚠️ HỦY TÀI NGUYÊN AWS TRÁNH PHÁT SINH CHI PHÍ (Destroy)

> [!WARNING]
> **NAT Gateway** và **6 máy ảo EC2** tính phí theo giờ trên AWS. Sau khi kết thúc thực hành và chụp ảnh minh chứng:

1. Thoát khỏi Bastion Host để quay về Git Bash máy cá nhân:
   ```bash
   exit
   ```
2. Tại thư mục `terraform` trên máy cá nhân, chạy lệnh hủy toàn bộ tài nguyên:
   ```bash
   cd /d/lab-devops/terraform
   terraform destroy -auto-approve
   ```

---

## 🛠️ 4. Bảng tra cứu lỗi thường gặp & Cách xử lý (Troubleshooting)

| Hiện tượng / Lỗi | Nguyên nhân | Cách khắc phục |
| :--- | :--- | :--- |
| `lookup registry.terraform.io: no such host` | DNS mạng cá nhân/Wi-Fi không phân giải được CDN HashiCorp | Đổi DNS máy tính sang Google `8.8.8.8` / `8.8.4.4` và chạy `ipconfig /flushdns`. |
| `ssh: connect to host ... port 22: Connection timed out` | Điền nhầm IP nội bộ `10.x.x.x` vào `allowed_ssh_cidr` thay vì Public IP | Lấy Public IP qua `curl -s https://checkip.amazonaws.com`, cập nhật vào `terraform.tfvars` và chạy `terraform apply -auto-approve`. |
| `bash: ansible: command not found` trên Windows | Ansible không chạy native trên Windows | Sử dụng Bastion Host làm Ansible Control Node (xem Phần 2 & 3). |
| `Permission denied (publickey)` khi chạy Ansible | Không chỉ định file private key khi SSH tới các node | Chạy `cp ~/key.pem ~/.ssh/id_rsa && chmod 600 ~/.ssh/id_rsa` trên Bastion. |
| `Unrecognized option: storage.journal.enabled` | MongoDB 7.0 đã gỡ bỏ tùy chọn `journal.enabled` | Đảm bảo file template `mongod.conf.j2` không chứa dòng `storage.journal.enabled`. |
| `Connection closed by UNKNOWN port 65535` khi chạy trên Bastion | Dùng file `inventory.ini` chứa `ProxyCommand` nhảy ngược vào chính Bastion | Dùng file inventory nội bộ chuẩn: `inventory/hosts.ini`. |
