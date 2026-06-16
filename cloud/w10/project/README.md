# W10 Project - Terraform + Minikube + Argo CD + Full Stack

Dự án này tích hợp toàn bộ stack:

- `app/` chứa app demo **Pixel Game Store**.
- `infra/terraform/` bootstrap phần hạ tầng local trên Minikube: build image local, cài Argo CD và apply root Application (AppOfApps pattern).
- `gitops/` chứa toàn bộ manifest Kubernetes/Argo CD:
  - `argocd/root.yaml` - Root Application (AppOfApps)
  - `argocd/apps/` - Child Applications trỏ tới các Kustomization bases
  - `apps/` - Kustomization bases cho từng application

Tất cả sources trỏ tới repo chính:

```text
https://github.com/BuiThanhNghiaDTU19122004/buithanhnghia-aws-accelerator-p2.git
```

## Cấu trúc thư mục

```text
w10/project/
├── app/
│   ├── Dockerfile
│   └── index.html
├── gitops/
│   ├── argocd/
│   │   ├── root.yaml              # AppOfApps pattern root
│   │   └── apps/
│   │       ├── game-store.yaml    # Sync Wave 2
│   │       ├── web.yaml           # Sync Wave 2 (nginx app)
│   │       ├── api.yaml           # Sync Wave 1 (Argo Rollouts)
│   │       ├── argo-rollouts.yaml # Sync Wave 0 (Helm)
│   │       ├── kube-prometheus-stack.yaml  # Sync Wave 0 (Helm)
│   │       └── monitoring-extras.yaml      # Sync Wave 2
│   └── apps/
│       ├── game-store/             # Game Store demo app
│       │   ├── kustomization.yaml
│       │   ├── namespace.yaml
│       │   ├── deployment.yaml
│       │   └── service.yaml
│       ├── web/                    # Web service (nginx)
│       │   ├── kustomization.yaml
│       │   └── web.yaml
│       ├── api/                    # API with Argo Rollouts
│       │   ├── kustomization.yaml
│       │   └── api.yaml
│       └── monitoring-extras/      # Monitoring resources
│           ├── kustomization.yaml
│           ├── namespace.yaml
│           └── alertmanager-smtp-secret.yaml
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
4. Terraform apply `gitops/argocd/root.yaml` (Root Application).
5. Argo CD tự động sync tất cả child applications theo sync-wave:
   - **Wave 0**: Argo Rollouts + Kube Prometheus Stack (prerequisites)
   - **Wave 1**: API (Rollout deployment)
   - **Wave 2**: Game Store, Web, Monitoring Extras

## Yêu cầu

- Terraform `>= 1.6.0`
- Minikube
- kubectl
- Một Minikube profile tên `minikube`
- Để sử dụng Argo Rollouts, cần API server endpoint có sẵn

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

**Lưu ý**: 
- Trước khi chạy `terraform apply`, hãy commit và push các thay đổi trong `gitops/` lên GitHub để Argo CD có thể clone được.
- Deploy có thể mất 2-3 phút vì Helm cần download charts và khởi động các components.

Kiểm tra Argo CD:

```powershell
kubectl --context minikube -n argocd get applications
```

Output sẽ hiển thị tất cả applications:
```
NAME                       REPO                                                           PATH                                          SYNC STATUS
root                       https://github.com/BuiThanhNghiaDTU19122004/...                cloud/w10/project/gitops/argocd/apps         Synced
game-store                 https://github.com/BuiThanhNghiaDTU19122004/...                cloud/w10/project/gitops/apps/game-store     Synced
web                        https://github.com/BuiThanhNghiaDTU19122004/...                cloud/w10/project/gitops/apps/web            Synced
api                        https://github.com/BuiThanhNghiaDTU19122004/...                cloud/w10/project/gitops/apps/api            Synced
argo-rollouts              https://argoproj.github.io/argo-helm                          N/A                                           Synced
kube-prometheus-stack      https://prometheus-community.github.io/helm-charts            N/A                                           Synced
monitoring-extras          https://github.com/BuiThanhNghiaDTU19122004/...                cloud/w10/project/gitops/apps/monitoring-extras  Synced
```

Kiểm tra các app:

```powershell
# Game Store
kubectl --context minikube -n demo get pods,svc -l app.kubernetes.io/name=game-store
minikube -p minikube service game-store -n demo --url

# Web (nginx)
kubectl --context minikube -n demo get pods,svc -l app=web
minikube -p minikube service web -n demo --url

# API (Rollout)
kubectl --context minikube -n demo get rollouts
kubectl --context minikube -n demo get pods,svc -l app=api

# Monitoring
kubectl --context minikube -n monitoring get all
kubectl --context minikube -n argo-rollouts get all

# Argo CD UI
minikube -p minikube service argocd-server -n argocd --url
# Login: admin / (lấy password từ secret argocd-initial-admin-secret)
```

## Các biến Terraform chính

| Biến | Mặc định | Ý nghĩa |
| --- | --- | --- |
| `kubeconfig_path` | `~/.kube/config` | Kubeconfig dùng để truy cập Minikube. |
| `kube_context` | `minikube` | Context Kubernetes Terraform sẽ dùng. |
| `minikube_profile` | `minikube` | Profile dùng cho lệnh `minikube image build`. |
| `argocd_namespace` | `argocd` | Namespace cài Argo CD. |
| `argocd_chart_version` | `null` | Có thể pin version chart Argo CD nếu cần. |

## Argo Rollouts - Canary Deployment

API service được deploy sử dụng **Argo Rollouts** cho canary strategy:
- 25% → 50% → 100% traffic shift
- Mỗi bước có pause 60s để quan sát
- Kích hoạt analysis template (yêu cầu Prometheus metrics)

Xem chi tiết rollout:
```powershell
kubectl --context minikube argo rollouts get rollout api -n demo --watch
```

## Kube Prometheus Stack - Monitoring

**Kube Prometheus Stack** được cài qua Helm với:
- **Prometheus**: Scrape metrics từ cluster
- **Grafana**: Dashboard visualization (admin/admin123)
- **AlertManager**: Email alerts (cần cấu hình SMTP password)

Xem Grafana:
```powershell
kubectl --context minikube port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```
Truy cập: http://localhost:3000

## Destroy

```powershell
terraform destroy -auto-approve
```

Destroy sẽ xóa:
- Argo CD Applications (root, game-store, web, api, monitoring-extras)
- Helm releases (Argo CD, Argo Rollouts, Kube Prometheus Stack)
- Namespaces (argocd, demo, monitoring, argo-rollouts)

Nếu muốn xóa luôn cluster local:

```powershell
minikube delete -p minikube
```

## Cập nhật manifests

Khi sửa bất kỳ file nào trong `gitops/`:

1. Commit và push lên GitHub:
```bash
git add cloud/w10/project/gitops/
git commit -m "Update: ..."
git push origin main
```

2. Argo CD sẽ tự động sync (do `automated.prune: true, selfHeal: true`)

3. Hoặc sync thủ công:
```powershell
kubectl --context minikube patch application root -n argocd --type merge -p '{"status":{"operationState":{"finishedAt":"2024-01-01T00:00:00Z"}}}'
# Hoặc dùng Argo CD CLI:
argocd app sync root
```
