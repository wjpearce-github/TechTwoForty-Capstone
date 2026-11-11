#!/bin/bash
# Runs once, as root, the first time the server boots.
set -euxo pipefail

dnf install -y docker
systemctl enable --now docker

# Settings for the app container. No password in here:
# the app reads it from Secrets Manager using the server's IAM role.
mkdir -p /etc/capstone
printf '%s\n' \
  "AWS_REGION=${region}" \
  "DB_HOST=${db_host}" \
  "DB_NAME=${db_name}" \
  "DB_SECRET_ARN=${secret_arn}" \
  "DB_SSLMODE=require" > /etc/capstone/app.env
chmod 600 /etc/capstone/app.env

# Nobody logs in over SSH. Admin access is through Session Manager.
systemctl disable --now sshd
