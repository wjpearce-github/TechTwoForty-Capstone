# RDS needs subnets in two Availability Zones, even for a single database.
# That is one of the two reasons the network has a "b" side.
resource "aws_db_subnet_group" "db" {
  name       = "capstone-db"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_db_instance" "app" {
  identifier        = "capstone-db"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_encrypted = true

  db_name  = "notes"
  username = "capstone"
  # RDS creates the password and keeps it in Secrets Manager.
  # It never appears in this code, in Terraform state, or in Git.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  availability_zone      = "${var.region}a"
  publicly_accessible    = false

  backup_retention_period = 1
  skip_final_snapshot     = true
  apply_immediately       = true
}
