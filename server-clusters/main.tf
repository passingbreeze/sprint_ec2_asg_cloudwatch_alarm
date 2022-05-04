terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket = "sprint-cloudwatch-alarm-webhook"
    key = "asg_server.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  profile = "gmail"
  region  = "ap-northeast-2"
}


data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_launch_template" "sprint_asg_template" {
  name_prefix = "sprint_cloudwatch_alarm"
  image_id = var.img_id
  instance_type = "t2.nano"
  key_name = "pb_sprint"
  user_data = filebase64("${path.module}/userdata.sh")
}

resource "aws_autoscaling_group" "sprint_asg" {
  vpc_zone_identifier  = data.aws_subnets.default.ids
  
  desired_capacity = 1
  min_size = 1
  max_size = 3

  force_delete = true
  enabled_metrics = ["GroupMinSize","GroupMaxSize","GroupDesiredCapacity","GroupInServiceInstances","GroupPendingInstances","GroupStandbyInstances","GroupTerminatingInstances","GroupTotalInstances"]
  
  launch_template {
    id = aws_launch_template.sprint_asg_template.id
    version = "$Latest"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [ desired_capacity ]
  }
  
  tag {
    key                 = "Name"
    value               = "sprint_cloudwatch_alarm_asg"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_in" {
  name = "sprint_asg_scale_in"
  autoscaling_group_name = aws_autoscaling_group.sprint_asg.name
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = -1
  cooldown = 60  
}

resource "aws_autoscaling_policy" "scale_out" {
  name = "sprint_asg_scale_out"
  autoscaling_group_name = aws_autoscaling_group.sprint_asg.name
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = 1
  cooldown = 60  
}

resource "aws_cloudwatch_metric_alarm" "scale_in_alarm" {
  alarm_description   = "Monitors CPU utilization for Sprint ASG"
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]
  alarm_name          = "sprint_scale_in_alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  threshold           = "40"
  evaluation_periods  = "2"
  period              = "60"
  statistic           = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.sprint_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "scale_out_alarm" {
  alarm_description   = "Monitors CPU utilization for Sprint ASG"
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]
  alarm_name          = "sprint_scale_out_alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  threshold           = "50"
  evaluation_periods  = "2"
  period              = "60"
  statistic           = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.sprint_asg.name
  }
}

resource "aws_autoscaling_notification" "scale_notifications" {
  group_names = [ aws_autoscaling_group.sprint_asg.name ]
  notifications = [ 
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR" 
  ]
  topic_arn = aws_sns_topic.noti_scale.arn
}

resource "aws_sns_topic" "noti_scale" {
  name = "noti_scale_alarm"
  # arn is an exported attribute
}