resource "aws_iam_role" "iam_for_lambda_credentials" {
  name               = "twitch_refresh_credentials_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  inline_policy {
    name   = "allow_ssm"
    policy = data.aws_iam_policy_document.allow_ssm.json
  }
}

data "archive_file" "lambda_credentials" {
  type        = "zip"
  source_dir  = "refresh_credentials_src"
  output_path = "lambda_credentials_payload.zip"
}

resource "aws_lambda_function" "twitch_refresh_credentials" {
  filename         = "lambda_credentials_payload.zip"
  function_name    = "twitch_refresh_credentials"
  role             = aws_iam_role.iam_for_lambda_credentials.arn
  handler          = "refresh_credentials.lambda_handler"
  architectures    = ["arm64"]
  source_code_hash = data.archive_file.lambda_credentials.output_base64sha256

  runtime = "python3.8"
}