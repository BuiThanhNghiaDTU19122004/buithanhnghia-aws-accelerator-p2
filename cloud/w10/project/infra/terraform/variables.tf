variable "kubeconfig_path" {
  type        = string
  description = "Path to the kubeconfig file used to access Minikube."
  default     = "~/.kube/config"
}

variable "kube_context" {
  type        = string
  description = "Kubernetes context for the Minikube cluster."
  default     = "minikube"
}

variable "minikube_profile" {
  type        = string
  description = "Minikube profile used for building the local app image."
  default     = "minikube"
}

variable "argocd_namespace" {
  type        = string
  description = "Namespace where Argo CD is installed."
  default     = "argocd"
}

variable "argocd_chart_version" {
  type        = string
  description = "Optional argo-cd Helm chart version. Leave null to use the latest chart from the repo."
  default     = null
}
