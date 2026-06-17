output "ec2_public_ip" {
  description = "Public IP of the Minikube EC2 instance (for SSH/SSM only)"
  value       = aws_instance.minikube.public_ip
}

output "ec2_instance_id" {
  description = "Instance ID for SSM Session Manager"
  value       = aws_instance.minikube.id
}

output "alb_dns_name" {
  description = "ALB DNS name for accessing all services"
  value       = aws_lb.app.dns_name
}

output "game_store_url" {
  description = "URL to access Game Store application"
  value       = "http://${aws_lb.app.dns_name}/"
}

output "argocd_url" {
  description = "URL to access ArgoCD UI"
  value       = "http://${aws_lb.app.dns_name}/argocd"
}

output "argocd_admin_password" {
  description = "Command to retrieve ArgoCD admin password"
  value       = <<-EOT
    kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  EOT
  sensitive   = true
}

output "access_instructions" {
  description = "Complete access instructions"
  value       = <<-EOT
    
    1. GAME STORE APPLICATION:
       URL: http://${aws_lb.app.dns_name}/
       
    2. ARGOCD UI:
       URL: http://${aws_lb.app.dns_name}/argocd
       
    3. GET ARGOCD ADMIN PASSWORD:
       Connect to EC2: aws ssm start-session --target ${aws_instance.minikube.id}
       Switch user: sudo su - ec2-user
       Run: kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
       
    4. ACCESS EC2 INSTANCE (for debugging):
       aws ssm start-session --target ${aws_instance.minikube.id}
       
  EOT
}

# Output cho debugging
output "target_group_arns" {
  description = "Target Group ARNs for debugging"
  value = {
    argocd     = aws_lb_target_group.argocd.arn
    game_store = aws_lb_target_group.game_store.arn
  }
}

# Output kiểm tra health check
output "health_check_instructions" {
  description = "Commands to check health status"
  value = <<-EOT
    # Check ALB health
    aws elbv2 describe-target-health --target-group-arn ${aws_lb_target_group.game_store.arn}
    
    # Check ArgoCD health
    aws elbv2 describe-target-health --target-group-arn ${aws_lb_target_group.argocd.arn}
  EOT
}