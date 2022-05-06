
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

