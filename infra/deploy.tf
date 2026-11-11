# ---------- Where images live ----------
resource "aws_ecr_repository" "app" {
  name                 = "capstone-api"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ---------- The deploy procedure, written down once ----------
# The pipeline can run this document and nothing else on the server.
resource "aws_ssm_document" "deploy" {
  name            = "capstone-deploy"
  document_type   = "Command"
  document_format = "YAML"
  content = templatefile("${path.module}/deploy-document.yaml", {
    region     = var.region
    registry   = split("/", aws_ecr_repository.app.repository_url)[0]
    image_repo = aws_ecr_repository.app.repository_url
  })
}

# ---------- Settings the pipeline looks up at deploy time ----------
# These change on every rebuild, so the pipeline reads them rather
# than you pasting new values into GitHub each time.
resource "aws_ssm_parameter" "instance_id" {
  name  = "/capstone/instance-id"
  type  = "String"
  value = aws_instance.app.id
}

resource "aws_ssm_parameter" "app_url" {
  name  = "/capstone/app-url"
  type  = "String"
  value = "https://${aws_cloudfront_distribution.app.domain_name}"
}

# ---------- The pipeline's identity ----------
# The GitHub identity provider already exists from CI/CD Unit 5.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "deploy" {
  name = "capstone-deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          # Only jobs running in your repo's production environment. GitHub names the
          # repo by owner and repo ID, so a recycled name can never get in.
          "token.actions.githubusercontent.com:sub" = "${var.github_subject}:environment:production"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "deploy" {
  name = "push-image-and-deploy"
  role = aws_iam_role.deploy.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PushToOurRepository"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid      = "RunOnlyTheDeployDocumentOnOurServer"
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = [aws_ssm_document.deploy.arn, aws_instance.app.arn]
      },
      {
        Sid      = "ReadDeploySettings"
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = [aws_ssm_parameter.instance_id.arn, aws_ssm_parameter.app_url.arn]
      },
      {
        # AWS does not let these two actions be limited to one resource.
        Sid      = "ActionsThatCannotBeScoped"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken", "ssm:GetCommandInvocation"]
        Resource = "*"
      },
    ]
  })
}
