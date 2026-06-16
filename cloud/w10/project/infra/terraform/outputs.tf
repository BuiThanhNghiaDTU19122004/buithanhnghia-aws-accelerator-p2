output "argocd_status_command" {
  description = "Command to check the Argo CD applications created by this project."
  value       = "kubectl --context ${var.kube_context} -n ${var.argocd_namespace} get applications"
}

output "argocd_url_command" {
  description = "Command to open the Argo CD server through Minikube."
  value       = "minikube -p ${var.minikube_profile} service argocd-server -n ${var.argocd_namespace} --url"
}

output "game_store_url_command" {
  description = "Command to open the demo app through Minikube."
  value       = "minikube -p ${var.minikube_profile} service game-store -n demo --url"
}
