terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  backend "s3" {
    bucket = "sprint-cloudwatch-alarm-webhook"
    key = "get_alarm_lambda.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  profile = "gmail"
  region  = "ap-northeast-2"
}

data "terraform_remote_state" "sns_event"{
  backend = "s3"

  config = {
    bucket = "sprint-cloudwatch-alarm-webhook"
    key = "asg_server.tfstate"
    region = "ap-northeast-2"
  }
}

# lambda rule

resource "aws_iam_role" "lambda_exec" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  policy_arn = "${aws_iam_policy.lambda_exec.arn}"
  role = "${aws_iam_role.lambda_exec.name}"
}

resource "aws_iam_policy" "lambda_exec" {
  policy = "${data.aws_iam_policy_document.lambda_exec.json}"
}

data "aws_iam_policy_document" "lambda_exec" {
  statement {
    sid       = "AllowSNSPermissions"
    effect    = "Allow"
    resources = ["arn:aws:sns:*"]

    actions = [
      "SNS:GetTopicAttributes",
        "SNS:SetTopicAttributes",
        "SNS:AddPermission",
        "SNS:RemovePermission",
        "SNS:DeleteTopic",
        "SNS:Subscribe",
        "SNS:ListSubscriptionsByTopic",
        "SNS:Publish"
    ]
  }

  statement {
    sid       = "AllowInvokingLambdas"
    effect    = "Allow"
    resources = ["arn:aws:lambda:ap-northeast-2:*:function:*"]
    actions   = ["lambda:InvokeFunction"]
  }

  statement {
    sid       = "AllowCreatingLogGroups"
    effect    = "Allow"
    resources = ["arn:aws:lambda:ap-northeast-2:*:function:*"]
    actions   = ["logs:CreateLogGroup"]
  }
  statement {
    sid       = "AllowWritingLogs"
    effect    = "Allow"
    resources = ["arn:aws:lambda:ap-northeast-2:*:function:*"]

    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutRetentionPolicy",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
    ]
  }
}


resource "random_pet" "cloudwatch_sprint_scale_alarm" {
  prefix = "cloudwatch-sprint-scale-alarm"
  length = 4
}

resource "aws_s3_bucket" "cloudwatch_sprint_scale_alarm_bucket" {
  bucket = random_pet.cloudwatch_sprint_scale_alarm.id
  force_destroy = true
}


data "archive_file" "cloudwatch_sprint_scale_alarm_webhook_file" {
  type = "zip"

  source_file  = "${path.module}/bin/handler"
  output_path = "${path.module}/handler.zip"
}

resource "aws_s3_object" "cloudwatch_sprint_scale_alarm_object" {
  bucket = aws_s3_bucket.cloudwatch_sprint_scale_alarm_bucket.id

  key    = "handler.zip"
  source = data.archive_file.cloudwatch_sprint_scale_alarm_webhook_file.output_path

  etag = filemd5(data.archive_file.cloudwatch_sprint_scale_alarm_webhook_file.output_path)
}

resource "aws_lambda_function" "cloudwatch_sprint_scale_alarm_webhook_function" {
  function_name = "cloudwatch_sprint_scale_alarm_webhook_function"

  s3_bucket = aws_s3_bucket.cloudwatch_sprint_scale_alarm_bucket.id
  s3_key    = aws_s3_object.cloudwatch_sprint_scale_alarm_object.key

  runtime = "go1.x"
  handler = "handler"

  source_code_hash = data.archive_file.cloudwatch_sprint_scale_alarm_webhook_file.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      HOOK_URL = "https://discord.com/api/webhooks/970748661388681336/o9yLba95y4asEZywwhZYTqH_RvSUFSV1BPlUjq57ydboPc60xDhJ2lZ28xwNdAwQBYPg"
    }
  }
}

resource "aws_cloudwatch_log_group" "cloudwatch_sprint_scale_alarm_logs" {
  name = "/aws/lambda/${aws_lambda_function.cloudwatch_sprint_scale_alarm_webhook_function.function_name}"

  retention_in_days = 30
}

resource "aws_sns_topic_subscription" "sprint_scale_alarm_event" {
  topic_arn = data.terraform_remote_state.sns_event.outputs.alarm_topic_arn
  protocol = "lambda"
  endpoint = aws_lambda_function.cloudwatch_sprint_scale_alarm_webhook_function.arn
}

resource "aws_lambda_permission" "with_sns" {
    statement_id = "AllowExecutionFromSNS"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.cloudwatch_sprint_scale_alarm_webhook_function.arn}"
    principal = "sns.amazonaws.com"
    source_arn = "${data.terraform_remote_state.sns_event.outputs.alarm_topic_arn}"
}
