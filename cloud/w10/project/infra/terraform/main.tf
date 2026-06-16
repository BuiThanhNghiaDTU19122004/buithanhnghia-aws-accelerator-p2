locals {
  app_dir              = abspath("${path.module}/../../app")
  app_image            = "game-store:local"
  argocd_root_manifest = abspath("${path.module}/../../gitops/argocd/root.yaml")
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}

resource "terraform_data" "game_store_image" {
  triggers_replace = [
    filesha256("${local.app_dir}/Dockerfile"),
    filesha256("${local.app_dir}/index.html"),
    local.app_image,
    var.minikube_profile
  ]

  provisioner "local-exec" {
    command = "minikube -p ${var.minikube_profile} image build -t ${local.app_image} ${local.app_dir}"
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = kubernetes_namespace_v1.argocd.metadata[0].name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  create_namespace = false
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      server = {
        service = {
          type = "NodePort"
        }
      }
    })
  ]
}

resource "terraform_data" "argocd_root" {
  input = {
    kube_context     = var.kube_context
    argocd_namespace = var.argocd_namespace
    root_manifest    = local.argocd_root_manifest
  }

  triggers_replace = [
    filesha256(local.argocd_root_manifest)
  ]

  provisioner "local-exec" {
    command = "kubectl --context ${self.input.kube_context} -n ${self.input.argocd_namespace} wait --for=condition=available deployment/argocd-server --timeout=300s && kubectl --context ${self.input.kube_context} apply -f ${self.input.root_manifest}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl --context ${self.input.kube_context} -n ${self.input.argocd_namespace} delete application root game-store --ignore-not-found=true && kubectl --context ${self.input.kube_context} delete namespace demo --ignore-not-found=true"
  }

  depends_on = [
    helm_release.argocd,
    terraform_data.game_store_image
  ]
}
