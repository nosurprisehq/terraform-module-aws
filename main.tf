# Provider -------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}

# CloudWatch -----------------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda_http" {
  name              = "/aws/lambda/${var.nosurprise_http_lambda_name}"
  retention_in_days = var.cloudwatch_logs_retention_in_days
}

# IAM ------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "lambda_http" {
  description = "Role used by No Surprise HTTP Lambda '${var.nosurprise_http_lambda_name}'"
  name        = var.iam_role_http_lambda_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_http_cloudwatch" {
  description = "Policy to allow the No Surprise HTTP Lambda '${var.nosurprise_http_lambda_name}' to write logs to CloudWatch"
  name        = "cloudwatch-logs"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:log-group:${aws_cloudwatch_log_group.lambda_http.name}:*",
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_http_iam" {
  description = "Policy to allow the No Surprise HTTP Lambda '${var.nosurprise_http_lambda_name}' to access and change user inline policies"
  name        = "user-management"
  path        = "/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:ListUsers"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetUserPolicy",
          "iam:PutUserPolicy",
          "iam:DeleteUserPolicy"
        ]
        Resource = "arn:aws:iam::*:user/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_http_cloudwatch" {
  role       = aws_iam_role.lambda_http.name
  policy_arn = aws_iam_policy.lambda_http_cloudwatch.arn
}

resource "aws_iam_role_policy_attachment" "lambda_http_iam" {
  role       = aws_iam_role.lambda_http.name
  policy_arn = aws_iam_policy.lambda_http_iam.arn
}

# Lambda ---------------------------------------------------------------------------------------------------------------
resource "null_resource" "artifact" {
  provisioner "local-exec" {
    command = <<EOT
      [ -f "nosurprise_aws_lambda.zip" ] && rm "nosurprise_aws_lambda.zip" 
      curl -L -o nosurprise_aws_lambda.zip "https://github.com/nosurprisehq/aws/releases/download/${var.nosurprise_control_plane_version}/aws_Linux_arm64.zip"
    EOT
  }
  triggers = {
    trigger = timestamp()
  }
}

resource "local_sensitive_file" "artifact" {
  depends_on = [null_resource.artifact]
  source     = "nosurprise_aws_lambda.zip"
  filename   = "nosurprise_aws_lambda.zip"
}

resource "aws_lambda_function" "http" {
  description      = "This function is the link between No Surprise servers and this AWS account"
  depends_on       = [local_sensitive_file.artifact, aws_cloudwatch_log_group.lambda_http]
  function_name    = var.nosurprise_http_lambda_name
  role             = aws_iam_role.lambda_http.arn
  filename         = "nosurprise_aws_lambda.zip"
  handler          = "main"
  runtime          = "provided.al2023"
  source_code_hash = local_sensitive_file.artifact.content_sha256
  architectures    = ["arm64"]
  timeout          = var.nosurprise_http_lambda_timeout
  environment {
    variables = {
      TIMEOUT     = var.nosurprise_http_lambda_timeout
      POLICY_NAME = var.iam_policy_name
    }
  }
  logging_config {
    application_log_level = "INFO"
    log_format            = "JSON"
    system_log_level      = "INFO"
  }
}

resource "aws_lambda_function_url" "http" {
  function_name      = aws_lambda_function.http.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "public_invoke" {
  statement_id           = "AllowPublicInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.http.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

# HTTP -----------------------------------------------------------------------------------------------------------------
resource "null_resource" "lambda_http_register" {
  depends_on = [aws_lambda_permission.public_invoke]
  provisioner "local-exec" {
    command = <<EOT
      curl -X PUT "${var.nosurprise_api}" \
           -H "Authorization: Bearer ${var.nosurprise_api_token}" \
           -H "Content-Type: application/json" \
           -d '${jsonencode({ endpoint = aws_lambda_function_url.http.function_url })}'
    EOT
  }
  triggers = {
    trigger  = aws_lambda_function.http.last_modified
    endpoint = var.nosurprise_api
    token    = var.nosurprise_api_token
  }
}
