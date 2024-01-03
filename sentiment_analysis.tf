resource "aws_iam_role" "iam_for_lambda_sentiment" {
  name               = "twitch_sentiment_analysis_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  inline_policy {
    name   = "allow_twitch_logs_s3"
    policy = data.aws_iam_policy_document.allow_twitch_logs_s3.json
  }
}

data "archive_file" "lambda_twitch_sentiment" {
  type        = "zip"
  source_dir  = "sentiment_analysis_src"
  output_path = "lambda_sentiment_payload.zip"
}

resource "aws_lambda_function" "twitch_sentiment_analysis" {
  filename         = "lambda_sentiment_payload.zip"
  function_name    = "twitch_sentiment_analysis"
  role             = aws_iam_role.iam_for_lambda_sentiment.arn
  handler          = "sentiment_analysis.lambda_handler"
  timeout          = 60
  architectures    = ["arm64"]
  source_code_hash = data.archive_file.lambda_twitch_scraper.output_base64sha256
  runtime          = "python3.8"
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