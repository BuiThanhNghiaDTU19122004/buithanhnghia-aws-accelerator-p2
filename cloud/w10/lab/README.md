# W10 Lab — RBAC + Gatekeeper + ESO + Trivy + Cosign

> GitOps-only: mọi thứ qua ArgoCD — không `kubectl apply` tay.
> Repo: <https://github.com/<user>/<repo>>

---

## Cấu trúc repo

```
.
├── rbac/
│   ├── roles.yaml             # Role (alice) + ClusterRole (bob, carol)
│   └── rolebindings.yaml      # 3 binding gán user vào role
├── gatekeeper/
│   ├── templates/             # 5 ConstraintTemplate (4 từ gatekeeper-library + 1 custom)
│   │   ├── 01-no-latest-tag.yaml
│   │   ├── 02-require-limits.yaml
│   │   ├── 03-no-root-user.yaml
│   │   ├── 04-no-host-network.yaml
│   │   └── 05-k8s-allowed-registry.yaml      # custom policy (Lab 1.3)
│   ├── constraints/           # 5 Constraint tương ứng (enforcementAction: deny)
│   ├── test-violations.yaml   # Pod vi phạm → expect REJECT
│   └── test-valid.yaml        # Pod hợp lệ → expect PASS
├── eso/
│   ├── secret-store.yaml      # SecretStore → AWS Secrets Manager
│   └── external-secret.yaml  # ExternalSecret: map key AWS → K8s Secret, refreshInterval
├── policies/
│   └── cluster-image-policy.yaml   # ClusterImagePolicy (Sigstore)
├── signing/
│   └── cosign.pub             # Public key verify image signature (KHÔNG commit private key)
├── .github/workflows/
│   └── build-push.yml         # CI: Trivy scan (exit-code 1) + Cosign sign
├── runbooks/                  # 2 runbook + 1 exception ADR (CVE chưa có patch)
├── argocd/
│   ├── root.yaml               # App-of-Apps
│   └── apps/
│       ├── rbac.yaml
│       ├── gatekeeper.yaml   # sync-wave: 0
│       ├── gatekeeper-templates.yaml    # sync-wave: 1
│       ├── gatekeeper-constraints.yaml  # sync-wave: 2
│       ├── eso.yaml                     # sync-wave: 0 (cài ESO operator)
│       ├── eso-config.yaml              # sync-wave: 1 (SecretStore + ExternalSecret)
│       ├── policy-controller.yaml       # sync-wave: 1 (Sigstore Policy Controller)
│       └── policies.yaml                # sync-wave: 2 (ClusterImagePolicy)
└── img/                        # Evidence screenshots
```

---

# Buổi sáng — RBAC + Gatekeeper

## Lab 1.1 — RBAC

### Thiết kế phân quyền

| User  | Kind | Role/ClusterRole     | Scope     | Quyền                                                |
| ----- | ---- | --------------------- | --------- | ----------------------------------------------------- |
| alice | User | `developer` (Role)    | ns `demo` | CRUD workload (deploy/pod/service) — chỉ trong ns `demo` |
| bob   | User | `sre` (ClusterRole)   | cluster   | Xem + thao tác pod toàn cụm (get/list/watch, delete, scale) |
| carol | User | `viewer` (ClusterRole)| cluster   | Chỉ đọc (get/list/watch), toàn cụm                    |

- alice → `Role` (namespace-scoped) vì chỉ làm việc trong `demo`
- bob/carol → `ClusterRole` vì cần quyền toàn cụm
- carol không có create/delete/update bất kỳ resource nào

### Nghiệm thu Lab 1.1

| Lệnh                                            | Kỳ vọng | Kết quả |
| ------------------------------------------------ | ------- | ------- |
| `can-i create deploy -n demo --as alice`         | yes     | ✅      |
| `can-i create deploy -n kube-system --as alice`  | no      | ✅       |
| `can-i get pods -A --as bob`                     | yes     | ✅       |
| `can-i delete nodes --as carol`                  | no      | ✅       |

> `--as` là impersonation (admin giả lập user) — đủ để chấm authorization, chưa cần authentication thật.

![Lab 1.1 — RBAC auth can-i](img/w10-morning-lab1.1.jpg)

---

## Lab 1.2 — Gatekeeper

### 4 luật enforcement (namespace `demo`)

| # | Rule                                       | ConstraintTemplate     | Risk |
| - | -------------------------------------------- | ------------------------ | ---- |
| 1 | Cấm image tag `:latest`                     | `K8sDisallowedTags`         | F-01 |
| 2 | Bắt buộc `resources.limits` (cpu + memory)  | `K8sRequiredResources`   | F-02 |
| 3 | Cấm `runAsUser: 0` (root)                   | `K8sPSPAllowedUsers`          | F-04 |
| 4 | Cấm `hostNetwork: true`                     | `K8sPSPHostNetworkingPorts`       | —    |

> 4 ConstraintTemplate này lấy từ `gatekeeper-library` (không cần tự viết Rego).

### Thứ tự deploy (sync-wave)

```
wave 0 → gatekeeper   (cài Gatekeeper qua Helm)
wave 1 → gatekeeper-templates    (4 ConstraintTemplate CRD)
wave 2 → gatekeeper-constraints  (4 Constraint, enforcementAction: deny)
```

> Mẹo: trước khi bật `deny`, chạy `enforcementAction: warn` (audit) để liệt kê resource đang vi phạm — tránh enforce xong sập cả platform.
> Bẫy: tự kiểm Rollout/app API của chính platform có lọt 4 luật không (image đã pin version, có `limits`, không set `runAsUser: 0`) — nếu platform tự bị chặn thì sửa cho hợp lệ trước khi bật enforce.

### Nghiệm thu Lab 1.2

| Test                                     | Kỳ vọng | Kết quả |
| ------------------------------------------ | ------- | ------- |
| Pod image `:latest`                        | reject  | ✅       |
| Pod thiếu `resources.limits`               | reject  | ✅       |
| Pod `runAsUser: 0`                         | reject  | ✅       |
| Pod `hostNetwork: true`                    | reject  | ✅       |
| Pod hợp lệ (pinned + limits + non-root)    | pass    | ✅       |

<!-- 🖼️ PLACEHOLDER ẢNH 1 -->
![Lab 1.2 — Test latest tag reject](img/w10-morning-lab1.2-test-latest.png)

<!-- 🖼️ PLACEHOLDER ẢNH 2 -->
![Lab 1.2 — Test resource limits reject](img/w10-morning-lab1.2-test-resource-limits.png)

<!-- 🖼️ PLACEHOLDER ẢNH 3 -->
![Lab 1.2 — Test runAsUser reject](img/w10-morning-lab1.2-test-runAsUser.png)

<!-- 🖼️ PLACEHOLDER ẢNH 4 -->
![Lab 1.2 — Test hostNetwork reject](img/w10-morning-lab1.2-test-hostNetwork.png)

<!-- 🖼️ PLACEHOLDER ẢNH 5 -->
![Lab 1.2 — Test valid pod pass](img/w10-morning-lab1.2-test-pass.png)

---

## Lab 1.3 — Custom Policy (Registry Whitelist)

> Đề bài cho chọn 1 trong 3 hướng — repo này chọn **whitelist registry** (đổi lại nếu bạn chọn hướng khác: reject `replicas > 5`, hoặc bắt buộc label `owner`).

Chặn tất cả image không xuất phát từ `ghcr.io/<user>/`. Chỉ registry của repo cá nhân được phép pull.

- ConstraintTemplate: `K8sAllowedRegistry` (tự viết Rego)
- Constraint: `allowed-registry` — `enforcementAction: deny`
- Parameter: `allowedRegistries: ["ghcr.io/<user>/"]`


### Nghiệm thu Lab 1.3

| Test                                  | Kỳ vọng | Kết quả |
| --------------------------------------- | ------- | ------- |
| Pod image `docker.io/nginx:1.25.3`      | reject  | ✅       |
| Pod image `ghcr.io/<user>/<app>:*`      | pass    | ✅       |

<!-- 🖼️ PLACEHOLDER ẢNH -->
![Lab 1.3 — ConstraintTemplate allowed-registry](img/w10-morning-lab1.3-allowed-registry.png)

---

# Buổi chiều — ESO + Supply Chain

## Lab 2.1 — ESO (External Secrets Operator)

Chuyển DB password từ Secret plaintext sang **AWS Secrets Manager + ESO**: đổi giá trị trên AWS → K8s Secret tự cập nhật trong `< 60s`, pod **không restart**. AWS credentials tạo bằng `kubectl create secret` — **KHÔNG** commit vào git.

### Thứ tự deploy

```
wave 0 → eso          (cài ESO operator qua Helm)
wave 1 → eso-config   (SecretStore + ExternalSecret)
```

> ESO operator (CRD) phải có **trước** khi apply SecretStore/ExternalSecret → tách 2 App + dùng sync-wave, đừng sync 1 lượt (lỗi `no matches for kind SecretStore`).
> `refreshInterval`: ngắn → spam AWS; dài → rotate chậm. Đặt sao để `< 60s`.

### Nghiệm thu Lab 2.1

| Kiểm tra                                       | Kỳ vọng                  | Kết quả |
| ------------------------------------------------- | --------------------------- | ------- |
| Đổi value trên AWS → `kubectl get secret -o jsonpath` | đổi theo `< refreshInterval` | ✅       |
| `kubectl get pod` sau khi rotate                  | AGE không đổi (no restart)  | ✅       |
| `grep -ri password` trong repo                   | không có secret thật        | ✅       |

<!-- 🖼️ PLACEHOLDER ẢNH 1 -->
![Lab 2.1 — SecretStore + ExternalSecret Synced trên ArgoCD](img/w10-afternoon-lab2.1-synced.png)

<!-- 🖼️ PLACEHOLDER ẢNH 2 -->
![Lab 2.1 — K8s Secret được tạo tự động](img/w10-afternoon-lab2.1-secret-created.png)

<!-- 🖼️ PLACEHOLDER ẢNH 3 -->
![Lab 2.1 — Đổi value trên AWS, Secret cập nhật < 60s](img/w10-afternoon-lab2.1-rotate.png)

<!-- 🖼️ PLACEHOLDER ẢNH 4 -->
![Lab 2.1 — Pod AGE không đổi sau rotate (no restart)](img/w10-afternoon-lab2.1-no-restart.png)

---

## Lab 2.2 — Trivy + Cosign (Supply Chain Security)

Cluster chỉ được chạy image đã scan sạch CVE và đã ký.

### Kiến trúc

```
CI (GitHub Actions)
  └── Build image
  └── Trivy scan → fail nếu có CVE HIGH/CRITICAL (exit-code 1)
  └── Cosign sign --key (private key từ GitHub Secret)
  └── Push image + signature lên registry (chỉ sau khi scan pass)

Cluster (Admission)
  └── Sigstore Policy Controller
  └── ClusterImagePolicy → verify signature bằng cosign.pub
  └── Namespace demo có label: policy.sigstore.dev/include=true
      (gắn label SAU khi image đã ký — gắn trước sẽ tự chặn app api)
```

### Files chính

| File                                 | Mục đích                                    |
| --------------------------------------- | ---------------------------------------------- |
| `.github/workflows/build-push.yml`     | CI: Trivy scan (exit-code 1) + Cosign sign     |
| `signing/cosign.pub`                   | Public key verify (KHÔNG commit private key)   |
| `policies/cluster-image-policy.yaml`   | ClusterImagePolicy với public key (`authorities.key.data`) |
| `argocd/apps/policy-controller.yaml`   | Cài Sigstore Policy Controller (wave 1)        |
| `argocd/apps/policies.yaml`             | Sync ClusterImagePolicy (wave 2)               |

### Nghiệm thu Lab 2.2

| Tình huống                 | Kỳ vọng          | Kết quả |
| --------------------------- | ------------------- | ------- |
| Push image chứa CVE HIGH    | CI đỏ                | ✅       |
| Deploy image chưa ký        | admission reject    | ✅       |
| Deploy image đã ký (từ CI)  | pass                 | ✅       |

> CVE mà vendor chưa fix → không block mãi: ghi exception ADR có thời hạn (xem `runbooks/`).

**CI xanh + image đã ký:**

<!-- 🖼️ PLACEHOLDER ẢNH -->
![Lab 2.2 — GitHub Actions run success](img/w10-afternoon-lab2.2-ci-run.png)

<!-- 🖼️ PLACEHOLDER ẢNH -->
![Lab 2.2 — CI xanh + image signed](img/w10-afternoon-lab2.2-ci-signed.png)

**Admission reject image chưa ký:**

<!-- 🖼️ PLACEHOLDER ẢNH -->
![Lab 2.2 — Admission reject unsigned image](img/w10-afternoon-lab2.2-admission-reject.png)

**Policy Controller + Policies Healthy trên ArgoCD:**

<!-- 🖼️ PLACEHOLDER ẢNH -->
![Lab 2.2 — Policy controller and policies healthy](img/w10-afternoon-lab2.2-policy-controller-healthy.png)

---

## Checklist nộp bài

### Buổi sáng

- [ ] `rbac/roles.yaml` — Role (alice) + ClusterRole (bob, carol)
- [ ] `rbac/rolebindings.yaml` — 3 binding
- [ ] `argocd/apps/rbac.yaml` — ArgoCD App cho RBAC
- [ ] `gatekeeper/templates/` — 5 ConstraintTemplate (4 luật từ gatekeeper-library + 1 custom)
- [ ] `gatekeeper/constraints/` — 5 Constraint với `enforcementAction: deny`
- [ ] `argocd/apps/gatekeeper-controller.yaml` — sync-wave: 0
- [ ] `argocd/apps/gatekeeper-templates.yaml` — sync-wave: 1
- [ ] `argocd/apps/gatekeeper-constraints.yaml` — sync-wave: 2
- [ ] `auth can-i` 4 lệnh đúng kỳ vọng
- [ ] 4 constraint reject vi phạm, pass pod hợp lệ
- [ ] Lab 1.3 custom Rego policy — reject registry ngoài whitelist
- [ ] Platform W9 vẫn xanh sau khi bật enforce

### Buổi chiều

- [ ] `eso/secret-store.yaml` + `eso/external-secret.yaml`
- [ ] `argocd/apps/eso.yaml` + `eso-config.yaml` — ArgoCD Apps (tách sync-wave: operator trước, config sau)
- [ ] `.github/workflows/build-push.yml` — Trivy scan (exit-code 1) + Cosign sign
- [ ] `signing/cosign.pub` — public key committed (KHÔNG commit private key)
- [ ] `policies/cluster-image-policy.yaml` — ClusterImagePolicy với public key
- [ ] `argocd/apps/policy-controller.yaml` — Sigstore Policy Controller
- [ ] `argocd/apps/policies.yaml` — ClusterImagePolicy sync
- [ ] ESO rotate `< 60s`, pod không restart
- [ ] CI đỏ khi CVE HIGH, xanh khi sạch
- [ ] Admission reject image chưa ký (`policy.sigstore.dev`)
- [ ] Image đã ký từ CI deploy pass
- [ ] `runbooks/` — 2 runbook + 1 exception ADR
- [ ] `git log -p | grep -i password` → không lộ secret thật
