
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

data "terraform_remote_state" "sns_event"{
  backend = "s3"

  config = {
    bucket = "sprint-cloudwatch-alarm-webhook"
    key = "asg_server.tfstate"
    region = "ap-northeast-2"
  }
}

resource "aws_lambda_permission" "with_sns" {
    statement_id = "AllowExecutionFromSNS"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.cloudwatch_sprint_scale_alarm_webhook_function.arn}"
    principal = "sns.amazonaws.com"
    source_arn = "${data.terraform_remote_state.sns_event.outputs.alarm_topic_arn}"
}

