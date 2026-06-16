# W10 Project - Terraform + Minikube + Argo CD

Dự án này gom lại thành một luồng thống nhất:

- `app/` chứa app demo **Pixel Game Store**.
- `infra/terraform/` bootstrap phần hạ tầng local trên Minikube: build image local, cài Argo CD và apply root Application.
- `gitops/` chứa toàn bộ manifest Kubernetes/Argo CD mà Argo CD sẽ sync từ chính repo này.

Argo CD không còn trỏ tới repo `gitops` riêng nữa. Source hiện tại là:

```text
https://github.com/BuiThanhNghiaDTU19122004/buithanhnghia-aws-accelerator-p2.git
```

Vì Argo CD clone từ GitHub, các thay đổi trong `gitops/` cần được commit và push lên repo này trước khi sync trên Minikube.

## Cấu trúc thư mục

```text
w10/project/
├── app/
│   ├── Dockerfile
│   └── index.html
├── gitops/
│   ├── argocd/
│   │   ├── root.yaml
│   │   └── apps/
│   │       └── game-store.yaml
│   └── apps/
│       └── game-store/
│           ├── kustomization.yaml
│           ├── namespace.yaml
│           ├── deployment.yaml
│           └── service.yaml
└── infra/
    └── terraform/
        ├── main.tf
        ├── outputs.tf
        ├── variables.tf
        └── versions.tf
```

## Luồng chạy

1. Minikube là Kubernetes cluster local.
2. Terraform build image `game-store:local` trực tiếp vào Minikube.
3. Terraform cài Argo CD bằng Helm chart.
4. Terraform apply `gitops/argocd/root.yaml`.
5. Argo CD sync `game-store` từ `cloud/w10/project/gitops/apps/game-store`.

## Yêu cầu

- Terraform `>= 1.6.0`
- Minikube
- kubectl
- Một Minikube profile tên `minikube`

Khởi động cluster trước:

```powershell
minikube start -p minikube
```

## Deploy

Chạy từ thư mục Terraform:

```powershell
cd w10/project/infra/terraform
terraform init
terraform apply -auto-approve
```

Kiểm tra Argo CD:

```powershell
kubectl --context minikube -n argocd get applications
```

Kiểm tra app:

```powershell
kubectl --context minikube -n demo get pods,svc
minikube -p minikube service game-store -n demo --url
```

Mở URL do `minikube service` trả về để xem app.

## Các biến Terraform chính

| Biến | Mặc định | Ý nghĩa |
| --- | --- | --- |
| `kubeconfig_path` | `~/.kube/config` | Kubeconfig dùng để truy cập Minikube. |
| `kube_context` | `minikube` | Context Kubernetes Terraform sẽ dùng. |
| `minikube_profile` | `minikube` | Profile dùng cho lệnh `minikube image build`. |
| `argocd_namespace` | `argocd` | Namespace cài Argo CD. |
| `argocd_chart_version` | `null` | Có thể pin version chart Argo CD nếu cần. |

## Destroy

```powershell
terraform destroy -auto-approve
```

Destroy sẽ xóa Argo CD Application, namespace `demo`, Helm release Argo CD và namespace `argocd`.
Nếu muốn xóa luôn cluster local:

```powershell
minikube delete -p minikube
```
