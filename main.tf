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
  name               = "twitch_scraper_role"
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

resource "aws_iam_role" "iam_for_lambda_sentiment" {
  name               = "twitch_sentiment_analysis_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  inline_policy {
    name = "allow_twitch_logs_s3"
    policy = data.aws_iam_policy_document.allow_twitch_logs_s3.json
  }
}

data "archive_file" "lambda_credentials" {
  type        = "zip"
  source_dir = "refresh_credentials_src"
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
  source_dir  = "twitch_scraper_src"
  output_path = "lambda_scraper_payload.zip"
}

resource "aws_lambda_function" "twitch_log_scraper" {
  filename      = "lambda_scraper_payload.zip"
  function_name = "twitch_log_scraper"
  role          = aws_iam_role.iam_for_lambda_scraper.arn
  handler       = "twitch_scraper.lambda_handler"
  timeout       = 900
  architectures  = ["arm64"]
  source_code_hash = data.archive_file.lambda_twitch_scraper.output_base64sha256
  runtime = "python3.8"
}

data "archive_file" "lambda_twitch_sentiment" {
  type        = "zip"
  source_dir = "sentiment_analysis_src"
  output_path = "lambda_sentiment_payload.zip"
}

resource "aws_lambda_function" "twitch_sentiment_analysis" {
  filename      = "lambda_sentiment_payload.zip"
  function_name = "twitch_sentiment_analysis"
  role          = aws_iam_role.iam_for_lambda_sentiment.arn
  handler       = "sentiment_analysis.lambda_handler"
  timeout       = 60
  architectures  = ["arm64"]
  source_code_hash = data.archive_file.lambda_twitch_scraper.output_base64sha256
  runtime = "python3.8"
}

resource "aws_s3_bucket" "twitch-scraper-logs" {
  bucket = "twitch-scraper-logs"

  tags = {
    Name        = "twitch-scraper-logs"
    Project     = "twitch_scraper"
  }
}

resource "aws_lambda_permission" "twitch-scraper-logs" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.twitch_sentiment_analysis.function_name
  principal = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.twitch-scraper-logs.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.twitch-scraper-logs.id
  
  lambda_function {
    lambda_function_arn = aws_lambda_function.twitch_sentiment_analysis.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw_logs/"
    filter_suffix       = ".log"
  }

}
