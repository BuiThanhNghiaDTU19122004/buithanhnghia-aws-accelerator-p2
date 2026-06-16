variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project" {
  type    = string
  default = "game-store-minikube"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type. Use t3.small for stability (ArgoCD needs RAM), but note it's NOT Free Tier eligible."
  default     = "t3.small"
}

variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "argocd_chart_version" {
  type        = string
  description = "Optional argo-cd Helm chart version."
  default     = null
}

variable "common_tags" {
  type = map(string)
  default = {
    Environment = "dev"
    Application = "game-store"
    ManagedBy   = "terraform"
    Owner       = "nghia"
  }
}
