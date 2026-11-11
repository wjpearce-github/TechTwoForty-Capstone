data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# The server's identity. It can do exactly three things:
# be managed through Systems Manager, pull images, read one secret.
resource "aws_iam_role" "app" {
  name = "capstone-app"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "app_ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "app_ecr" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy" "app_secret" {
  name = "read-database-secret"
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_db_instance.app.master_user_secret[0].secret_arn
    }]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "capstone-app"
  role = aws_iam_role.app.name
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  # IMDSv2 only. The hop limit of 2 lets the container,
  # one network hop further in, reach the role's credentials.
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    encrypted = true
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    region     = var.region
    db_host    = aws_db_instance.app.address
    db_name    = aws_db_instance.app.db_name
    secret_arn = aws_db_instance.app.master_user_secret[0].secret_arn
  })
  user_data_replace_on_change = true

  # The first boot installs Docker, which needs the NAT gateway.
  # Nothing above mentions the NAT, so say it out loud.
  depends_on = [aws_route_table_association.private_a]

  # A newer Amazon Linux image should not replace a running server by
  # surprise on some later apply. Every rebuild gets the newest one anyway.
  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = "capstone-app" }
}
