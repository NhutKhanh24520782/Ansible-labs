# Ansible Playbook: Triển khai MongoDB 7.0 Replica Set (5 Nodes)

Bộ Ansible Automation này được thiết kế theo chuẩn **Senior DevOps Best Practices** để tự động cài đặt, cấu hình và khởi tạo cụm **MongoDB 7.0 Replica Set** (`rs0`) gồm **5 nodes** trên hệ điều hành Ubuntu (20.04/22.04/24.04 LTS).

---

## 📁 1. Cấu trúc thư mục

```text
ansible/
├── ansible.cfg                          # Cấu hình Ansible chung (SSH user, timeout, privilege escalation)
├── site.yml                             # Entrypoint playbook chính
├── inventory/
│   ├── hosts.ini                        # Khai báo 5 MongoDB nodes & IP kết nối
│   └── group_vars/
│       └── all.yml                      # Biến toàn cục (port 27017, replSet rs0, GPG key, repository)
├── playbooks/
│   └── deploy-mongodb-cluster.yml       # Playbook điều phối role mongodb
├── roles/
│   └── mongodb/
│       ├── defaults/
│       │   └── main.yml                 # Giá trị mặc định của biến role
│       ├── handlers/
│       │   └── main.yml                 # Handlers restart / reload mongod
│       ├── tasks/
│       │   ├── main.yml                 # Master task file liên kết các tasks con
│       │   ├── install.yml              # Cài đặt MongoDB 7.0 & mongosh chính thức
│       │   ├── configure.yml            # Triển khai mongod.conf, enable service
│       │   ├── replica_set.yml          # Khởi tạo Replica Set rs0 (Idempotent)
│       │   └── verify.yml               # Kiểm tra Cluster Health (1 PRIMARY & 4 SECONDARY)
│       └── templates/
│           └── mongod.conf.j2           # Template cấu hình MongoDB 7.0 chuẩn
└── README.md                            # Hướng dẫn chi tiết
```

---

## ⚙️ 2. Các điểm kỹ thuật nổi bật (Senior DevOps Best Practices)

1. **Chuẩn APT Keyring Ubuntu mới:** Không dùng lệnh `apt-key` đã bị deprecated, sử dụng keyring `/usr/share/keyrings/mongodb-server-7.0.gpg` với `signed-by`.
2. **Version Pinning (dpkg_selections: hold):** Tự động khóa phiên bản các gói MongoDB để ngăn ngừa lệnh `apt upgrade` vô tình gây downtime hoặc lệch phiên bản giữa các nodes.
3. **Tính Idempotent tuyệt đối:**
   - Kiểm tra `rs.status().ok` trước khi gọi `rs.initiate()`.
   - Nếu chạy lại (re-run), playbook tự động kiểm tra danh sách member hiện hữu và chỉ bổ sung node mới nếu thiếu bằng `rs.add()`, không bao giờ báo lỗi `already initialized`.
4. **Flush Handlers:** Đảm bảo `mongod` được restart và áp dụng cấu hình `replSetName: rs0` trước khi thực hiện bước khởi tạo replica set.
5. **Đồng bộ hóa & Bầu chọn tự động (Wait/Retry Loop):** Playbook tích hợp vòng lặp chờ PRIMARY được bầu chọn và chờ 4 SECONDARY đồng bộ xong trước khi xác thực.
6. **Xác thực tự động (Assertions):** Bắt buộc dừng và báo lỗi cụ thể nếu cụm không đủ chính xác 1 PRIMARY và 4 SECONDARY.

---

## 🚀 3. Hướng dẫn triển khai

### Bước 1: Cập nhật địa chỉ IP trong Inventory
Mở file `ansible/inventory/hosts.ini` và thay thế bằng các địa chỉ IP thực tế của 5 máy chủ:

```ini
[mongodb_nodes]
mongo-node-1 ansible_host=10.0.1.11 mongo_bind_ip=10.0.1.11 mongo_node_id=0
mongo-node-2 ansible_host=10.0.1.12 mongo_bind_ip=10.0.1.12 mongo_node_id=1
mongo-node-3 ansible_host=10.0.1.13 mongo_bind_ip=10.0.1.13 mongo_node_id=2
mongo-node-4 ansible_host=10.0.1.14 mongo_bind_ip=10.0.1.14 mongo_node_id=3
mongo-node-5 ansible_host=10.0.1.15 mongo_bind_ip=10.0.1.15 mongo_node_id=4

[mongodb_nodes:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/your-key.pem  # <--- Thay đổi đường dẫn private key nếu cần
```

> **Lưu ý:**
> - `ansible_host`: Địa chỉ IP dùng để kết nối SSH (Public IP hoặc Private IP nếu qua VPN/Bastion).
> - `mongo_bind_ip`: Địa chỉ IP nội bộ mà MongoDB lắng nghe và các node trong cluster dùng để kết nối với nhau.

---

### Bước 2: Kiểm tra kết nối SSH (Ad-hoc command)
```bash
cd ansible
ansible -i inventory/hosts.ini mongodb_nodes -m ping
```

---

### Bước 3: Kiểm tra cú pháp (Syntax Check)
```bash
ansible-playbook -i inventory/hosts.ini site.yml --syntax-check
```

---

### Bước 4: Thực thi triển khai
```bash
ansible-playbook -i inventory/hosts.ini site.yml
```

---

## 📊 4. Kết quả mong đợi

Khi playbook chạy xong bước `verify.yml`, output sẽ hiển thị xác thực thành công:

```text
TASK [mongodb : Xác thực Cluster Health đạt chuẩn (Chính xác 1 PRIMARY và 4 SECONDARY)] **********
ok: [mongo-node-1] => {
    "msg": "Xác thực Replica Set 'rs0' THÀNH CÔNG: Đầy đủ 5 nodes (1 PRIMARY, 4 SECONDARY) sẵn sàng hoạt động!"
}

TASK [mongodb : Hiển thị bảng tổng kết trạng thái Replica Set] *************************************
ok: [mongo-node-1] => {
    "msg": {
        "cluster_name": "rs0",
        "total_members": 5,
        "primary": [
            "10.0.1.11:27017"
        ],
        "secondaries": [
            "10.0.1.12:27017",
            "10.0.1.13:27017",
            "10.0.1.14:27017",
            "10.0.1.15:27017"
        ]
    }
}
```

---

## 🔍 5. Kiểm tra thủ công trực tiếp trên Server (Manual Verification)

Truy cập SSH vào `mongo-node-1`:
```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<IP_NODE_1>
mongosh --port 27017
```

Chạy lệnh trong MongoDB Shell (`mongosh`):
```javascript
// Xem trạng thái tổng quát
rs.status()

// Kiểm tra node hiện tại có phải PRIMARY không
db.hello().isWritablePrimary

// Xem danh sách cấu hình các members
rs.conf().members
```

