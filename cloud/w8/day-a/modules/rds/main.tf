resource "aws_security_group" "rds" {
  name   = "rds-sg"
  vpc_id = var.vpc_id

  ingress {
    description     = "MySQL from EC2 only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.ec2_security_group]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "rds-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_db_instance" "mysql" {
  identifier             = "nghia-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"

  allocated_storage      = 20
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = {
    Name = "private-mysql"
  }
}