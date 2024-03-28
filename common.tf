provider "aws" {
  region = ""
  default_tags {
    tags = {
      project = "twitch_sentiment_analysis"
    }
  }
}


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

data "aws_iam_policy_document" "allow_twitch_logs_s3" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::twitch-scraper-logs"]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:*Object"]
    resources = ["arn:aws:s3:::twitch-scraper-logs/*"]
  }
}

data "aws_iam_policy_document" "allow_invoke_lambda" {
  statement {
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = ["arn:aws:lambda:eu-west-2:192225688557:function:twitch_refresh_credentials"]
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
