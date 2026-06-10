run "aws_infra_contract" {
  command = plan

  assert {
    condition     = aws_lb.app.load_balancer_type == "application"
    error_message = "ALB phải là loại application load balancer"
  }

  assert {
    condition     = aws_lb.app.internal == false
    error_message = "ALB phải được expose public trên Internet"
  }

  assert {
    condition     = aws_lb_listener.http.port == 80
    error_message = "Listener phải lắng nghe port 80"
  }

  assert {
    condition     = aws_lb_target_group.app.port == var.app_port
    error_message = "Target group phải trỏ đúng port ứng dụng"
  }

  assert {
    condition     = aws_lb_target_group.app.target_type == "instance"
    error_message = "Target group phải attach vào EC2 instance"
  }

  assert {
    condition     = length(tolist(aws_security_group.alb.ingress)) > 0 && tolist(aws_security_group.alb.ingress)[0].from_port == 80 && tolist(aws_security_group.alb.ingress)[0].to_port == 80
    error_message = "Security group của ALB phải cho phép HTTP inbound trên port 80"
  }

  assert {
    condition     = length(tolist(aws_security_group.ec2.ingress)) > 0 && tolist(aws_security_group.ec2.ingress)[0].from_port == var.app_port && tolist(aws_security_group.ec2.ingress)[0].to_port == var.app_port
    error_message = "Security group của EC2 phải cho phép traffic từ ALB tới port ứng dụng"
  }

  assert {
    condition     = aws_instance.k8s.instance_type == var.instance_type
    error_message = "EC2 phải dùng instance type được cấu hình"
  }

  assert {
    condition     = aws_instance.k8s.associate_public_ip_address == true
    error_message = "EC2 phải có public IP để kind/NodePort phục vụ ALB"
  }

  assert {
    condition     = aws_lb_target_group_attachment.app.port == var.app_port
    error_message = "Target group attachment phải dùng đúng port ứng dụng"
  }
}
