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

resource "aws_iam_role" "iam_for_lambda" {
  name               = "twitch_refresh_credentials_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  inline_policy {
    name = "allow_ssm"
    policy = data.aws_iam_policy_document.allow_ssm.json
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "refresh_credentials.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "twitch_refresh_credentials" {
  filename      = "lambda_function_payload.zip"
  function_name = "twitch_refresh_credentials"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "refresh_credentials.lambda_handler"
  architectures  = ["arm64"]
  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.8"

}
