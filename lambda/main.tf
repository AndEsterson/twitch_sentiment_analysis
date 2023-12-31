data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "allow_ssm" {
  statement {
    effect = "Allow"

    actions = [
                "ssm:PutParameter",
                "ssm:DeleteParameter",
                "ssm:GetParameterHistory",
                "ssm:GetParametersByPath",
                "ssm:GetParameters",
                "ssm:GetParameter",
                "ssm:DeleteParameters"
            ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "allow_ssm_read" {
  statement {
    effect = "Allow"

    actions = [
                "ssm:GetParameterHistory",
                "ssm:GetParametersByPath",
                "ssm:GetParameters",
                "ssm:GetParameter"
            ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "allow_s3" {
  statement {
    effect = "Allow"

    actions = [
                "ssm:PutParameter",
                "ssm:DeleteParameter",
                "ssm:GetParameterHistory",
                "ssm:GetParametersByPath",
                "ssm:GetParameters",
                "ssm:GetParameter",
                "ssm:DeleteParameters"
            ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "allow_twitch_logs_s3" {
    statement {
            effect = "Allow"
            actions = ["s3:ListBucket"]
            resources = ["arn:aws:s3:::twitch-scraper-logs"]
        }
    statement {
            effect = "Allow"
            actions = ["s3:*Object"]
            resources = ["arn:aws:s3:::twitch-scraper-logs/*"]
        }
}

data "aws_iam_policy_document" "allow_invoke_lambda" {
    statement {
            effect = "Allow"
            actions = ["lambda:InvokeFunction"]
            resources = ["arn:aws:lambda:eu-west-2:192225688557:function:twitch_refresh_credentials"]
        }
}

resource "aws_iam_role" "iam_for_lambda_scraper" {
  name               = "lambda_twitch_scraper_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  inline_policy {
    name = "allow_ssm_read"
    policy = data.aws_iam_policy_document.allow_ssm_read.json
  }
  inline_policy {
   name = "allow_twitch_logs_s3"
   policy = data.aws_iam_policy_document.allow_twitch_logs_s3.json
  }
  inline_policy {
   name = "allow_invoke_lambda"
   policy = data.aws_iam_policy_document.allow_invoke_lambda.json
  }
}

resource "aws_iam_role" "iam_for_lambda_credentials" {
  name               = "twitch_refresh_credentials_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  inline_policy {
    name = "allow_ssm"
    policy = data.aws_iam_policy_document.allow_ssm.json
  }
}

data "archive_file" "lambda_credentials" {
  type        = "zip"
  source_file = "refresh_credentials.py"
  output_path = "lambda_credentials_payload.zip"
}

resource "aws_lambda_function" "twitch_refresh_credentials" {
  filename      = "lambda_credentials_payload.zip"
  function_name = "twitch_refresh_credentials"
  role          = aws_iam_role.iam_for_lambda_credentials.arn
  handler       = "refresh_credentials.lambda_handler"
  architectures  = ["arm64"]
  source_code_hash = data.archive_file.lambda_credentials.output_base64sha256

  runtime = "python3.8"

}

data "archive_file" "lambda_twitch_scraper" {
  type        = "zip"
  source_file = "twitch_scraper.py"
  output_path = "lambda_scraper_payload.zip"
}

resource "aws_lambda_function" "twitch_log_scraper" {
  filename      = "lambda_scraper_payload.zip"
  function_name = "twitch_log_scraper"
  role          = aws_iam_role.iam_for_lambda_scraper.arn
  handler       = "twitch_scraper.lambda_handler"
  timeout       = 300
  architectures  = ["arm64"]
  source_code_hash = data.archive_file.lambda_twitch_scraper.output_base64sha256
  runtime = "python3.8"
}
