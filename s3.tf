resource "aws_s3_bucket" "twitch-scraper-logs" {
  bucket = "twitch-scraper-logs"

  tags = {
    Name    = "twitch-scraper-logs"
    Project = "twitch_scraper"
  }
}

resource "aws_lambda_permission" "twitch-scraper-logs" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.twitch_sentiment_analysis.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.twitch-scraper-logs.arn
}