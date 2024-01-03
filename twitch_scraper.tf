resource "aws_iam_role" "iam_for_lambda_scraper" {
  name               = "twitch_scraper_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  inline_policy {
    name   = "allow_ssm_read"
    policy = data.aws_iam_policy_document.allow_ssm_read.json
  }
  inline_policy {
    name   = "allow_twitch_logs_s3"
    policy = data.aws_iam_policy_document.allow_twitch_logs_s3.json
  }
  inline_policy {
    name   = "allow_invoke_lambda"
    policy = data.aws_iam_policy_document.allow_invoke_lambda.json
  }
}

data "archive_file" "lambda_twitch_scraper" {
  type        = "zip"
  source_dir  = "twitch_scraper_src"
  output_path = "lambda_scraper_payload.zip"
}

resource "aws_lambda_function" "twitch_log_scraper" {
  filename         = "lambda_scraper_payload.zip"
  function_name    = "twitch_log_scraper"
  role             = aws_iam_role.iam_for_lambda_scraper.arn
  handler          = "twitch_scraper.lambda_handler"
  timeout          = 900
  architectures    = ["arm64"]
  source_code_hash = data.archive_file.lambda_twitch_scraper.output_base64sha256
  runtime          = "python3.8"
}