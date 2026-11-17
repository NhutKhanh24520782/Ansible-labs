# Hướng dẫn đóng góp (Contributing Guidelines)

Dự án này phục vụ bài tập môn học **NT548 - DevOps**. Để đảm bảo tính nhất quán và chất lượng mã nguồn, vui lòng tuân thủ quy tắc sau:

## 1. Quy ước đặt tên nhánh (Branching Convention)
Tạo nhánh mới từ `main` theo định dạng:
```bash
feature/<mã-sinh-viên-hoặc-mã-lab>-<tên-tính-năng>
```
*Ví dụ:*
- `feature/21520000-lab01-vpc`
- `feature/lab02-ci-cd-pipeline`

## 2. Quy ước Commit Message
Commit message phải rõ ràng, tuân thủ cấu trúc:
```text
[<mã>] <nội dung commit>
```
*Ví dụ:*
- `[LAB01] Khởi tạo module VPC và route tables`
- `[LAB02] Cấu hình GitHub Actions OIDC assume role`
- `[DOCS] Bổ sung hướng dẫn SSH Bastion Host`

## 3. Quy trình Pull Request (PR) & Review
1. Đẩy nhánh lên repository: `git push origin <tên-nhánh>`
2. Tạo Pull Request trỏ vào nhánh `main`.
3. Kiểm tra các bước CI/CD checks (Checkov scan, Terraform validate/plan) chạy thành công.
4. **Quy tắc bắt buộc:** Cần ít nhất **1 approval/review** từ thành viên nhóm/giảng viên trước khi merge vào `main`.
5. Sau khi merge, xóa nhánh feature để giữ repository gọn gàng.

