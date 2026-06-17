output "ec2_public_ip" {
  description = "Public IP of the Minikube EC2 instance"
  value       = aws_instance.minikube.public_ip
}

output "ec2_instance_id" {
  description = "Instance ID for SSM Session Manager"
  value       = aws_instance.minikube.id
}

output "argocd_access_instructions" {
  description = "Instructions to access ArgoCD UI"
  value       = <<-EOT
    1. Connect to EC2 via SSM: aws ssm start-session --target ${aws_instance.minikube.id}
    2. Switch to ec2-user: sudo su - ec2-user
    3. ArgoCD is exposed on fixed NodePort 30080.
    4. Access UI at: http://${aws_instance.minikube.public_ip}:30080
    5. Get initial admin password: kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  EOT
}

output "game_store_access_instructions" {
  description = "Instructions to access Game Store App"
  value       = <<-EOT
    1. Connect to EC2 via SSM: aws ssm start-session --target ${aws_instance.minikube.id}
    2. Switch to ec2-user: sudo su - ec2-user
    3. Wait for ArgoCD to sync the app (check UI), then get GameStore NodePort: 
       kubectl get svc game-store -n demo -o jsonpath='{.spec.ports[0].nodePort}'
    4. Access Game Store at: http://${aws_instance.minikube.public_ip}:<NODE_PORT>
  EOT
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}