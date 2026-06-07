# Ứng dụng web AWS đơn giản với Terraform

Dự án Terraform này triển khai một ứng dụng web đơn giản trên AWS gồm:

- S3 + DynamoDB bootstrap cho remote state và khóa state
- VPC với public subnet và private subnet
- EC2 chạy frontend/backend API
- RDS MySQL private làm database
- S3 static website public làm frontend

## Cấu hình nhanh

Sao chép file mẫu `terraform.tfvars.example` thành `terraform.tfvars` rồi chỉnh giá trị phù hợp.

Ví dụ `terraform.tfvars`:

```hcl
static_bucket_name = "nghia-static-assets-bucket-201023212626"
db_password        = "nghia123"
allowed_ssh_cidr   = "YOUR_PUBLIC_IP/32"
```

Nhớ đổi `allowed_ssh_cidr` thành public IP của bạn theo định dạng `/32` nếu deploy thật.

## 1. Tạo Terraform backend

Chạy một lần trước khi deploy app:

```powershell
cd bootstrap
$env:TF_CLI_CONFIG_FILE = "NUL"
terraform init
terraform apply
```

Phần bootstrap sẽ tạo:

- S3 bucket: `nghia-tfstate-bucket-201023212626`
- DynamoDB table: `terraform-locks`

## 2. Triển khai ứng dụng

Quay về thư mục gốc của dự án:

```powershell
cd ..
$env:TF_CLI_CONFIG_FILE = "NUL"
terraform init -reconfigure
terraform apply
```

Sau khi apply xong, xem kết quả bằng:

```powershell
terraform output
```

Các output chính:

- `s3_website_url`: địa chỉ frontend public trên S3
- `ec2_web_url`: địa chỉ frontend/API trên EC2
- `rds_endpoint`: endpoint RDS MySQL private

## 3. Kiểm tra

Mở `s3_website_url`, nhập message và nhấn Save. Nếu thành công, frontend trên S3 sẽ gọi API trên EC2 và lưu dữ liệu vào RDS MySQL.

Bạn cũng có thể test API trực tiếp:

```powershell
Invoke-WebRequest "$(terraform output -raw ec2_web_url)/api/health" -UseBasicParsing
Invoke-WebRequest "$(terraform output -raw ec2_web_url)/api/messages" -UseBasicParsing
```

## 4. Xoá tài nguyên

Xoá app trước, giữ backend state lại trong khi Terraform đang xóa resource:

```powershell
$env:TF_CLI_CONFIG_FILE = "NUL"
terraform destroy
```

Sau đó xoá backend bootstrap:

```powershell
cd bootstrap
$env:TF_CLI_CONFIG_FILE = "NUL"
terraform destroy
```

Nếu destroy bootstrap báo S3 bucket không rỗng, hãy empty bucket `nghia-tfstate-bucket-201023212626` trước rồi chạy lại `terraform destroy`.
