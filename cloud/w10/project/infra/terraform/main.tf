# ---------------------------------------------------------
# Data Sources
# ---------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ec2_subnet_id = data.aws_subnets.default.ids[0]
  tags          = merge(var.common_tags, { Project = var.project })
}

# ---------------------------------------------------------
# IAM Role for EC2 (Enable SSM Session Manager)
# ---------------------------------------------------------
resource "aws_iam_role" "ec2" {
  name = "${var.project}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-instance-profile"
  role = aws_iam_role.ec2.name
}

# ---------------------------------------------------------
# Security Group
# ---------------------------------------------------------
resource "aws_security_group" "ec2" {
  name        = "${var.project}-ec2-sg"
  description = "Allow ALB to access fixed Minikube NodePorts"
  vpc_id      = data.aws_vpc.default.id

  # CRITICAL: Only allow traffic originating from the ALB SG
  ingress {
    description     = "Allow ArgoCD from ALB"
    from_port       = 30080
    to_port         = 30080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Allow Game Store from ALB"
    from_port       = 30081
    to_port         = 30081
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project}-ec2-sg" })
}

resource "aws_instance" "minikube" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = local.ec2_subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name

  # Inject local files into user_data
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    argocd_namespace     = var.argocd_namespace
    argocd_chart_version = var.argocd_chart_version
    app_dockerfile       = file("${path.module}/../../app/Dockerfile")
    app_index_html       = file("${path.module}/../../app/index.html")
    argocd_root_manifest = file("${path.module}/../../gitops/argocd/root.yaml")
  })
  
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 30 # Minikube + Docker images need > 20GB
    volume_type = "gp3"
  }

  tags = merge(local.tags, { Name = "${var.project}-minikube-host" })
}

# ---------------------------------------------------------
# Security Groups (Hardened)
# ---------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "Allow HTTP from Internet to ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # TODO: Restrict to your IP in prod
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project}-alb-sg" })
}

# ---------------------------------------------------------
# Application Load Balancer (ALB)
# ---------------------------------------------------------
resource "aws_lb" "app" {
  name               = "${var.project}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = slice(data.aws_subnets.default.ids, 0, 2) # ALB needs at least 2 AZs

  tags = merge(local.tags, { Name = "${var.project}-alb" })
}

# Target Group for ArgoCD (Fixed NodePort 30080)
resource "aws_lb_target_group" "argocd" {
  name        = "${var.project}-tg-argocd"
  port        = 30080
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/login" # ArgoCD login page is a safe health check endpoint
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# Target Group for Game Store App (Fixed NodePort 30081)
resource "aws_lb_target_group" "game_store" {
  name        = "${var.project}-tg-gs"
  port        = 30081
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

# Attach EC2 to both Target Groups
resource "aws_lb_target_group_attachment" "argocd" {
  target_group_arn = aws_lb_target_group.argocd.arn
  target_id        = aws_instance.minikube.id
  port             = 30080
}

resource "aws_lb_target_group_attachment" "game_store" {
  target_group_arn = aws_lb_target_group.game_store.arn
  target_id        = aws_instance.minikube.id
  port             = 30081
}

# ---------------------------------------------------------
# ALB Listener & Advanced Routing Rules
# ---------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  # Default action: Return 404 if Host header doesn't match any rule
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404 Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "argocd" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.argocd.arn
  }

  condition {
    path_pattern {
      values = ["/argocd*", "/login*", "/applications*", "/settings*", "/user-info*"]
    }
  }
}

# Rule 2: Route app.local to Game Store Target Group
resource "aws_lb_listener_rule" "game_store" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.game_store.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}