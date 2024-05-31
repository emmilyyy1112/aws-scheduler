resource "aws_iam_role" "lambda_role" {
  name = "ecs_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "ecs_policy" {
  name = "ecs_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ecs:ListTasks",
          "ecs:StopTask",
          "ecs:RunTask",
          "iam:PassRole"
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.ecs_policy.arn
}

resource "aws_lambda_function" "ecs_scheduler" {
  filename         = "lambda_function.zip"
  function_name    = "ecs_scheduler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.8"
  source_code_hash = filebase64sha256("lambda_function.zip")

  environment {
    variables = {
      CLUSTER_NAME = "smx-cluster-svc-dev"
    }
  }
}

resource "aws_cloudwatch_event_rule" "stop_ecs" {
  name                = "stop_ecs"
  description         = "Stop ECS tasks every Friday at 6 PM"
  schedule_expression = "cron(0 18 ? * FRI *)"
}

resource "aws_cloudwatch_event_rule" "start_ecs" {
  name                = "start_ecs"
  description         = "Start ECS tasks every Monday at 6 AM"
  schedule_expression = "cron(0 6 ? * MON *)"
}

resource "aws_cloudwatch_event_target" "stop_ecs_target" {
  rule      = aws_cloudwatch_event_rule.stop_ecs.name
  target_id = "stop_ecs"
  arn       = aws_lambda_function.ecs_scheduler.arn
  input     = jsonencode({ "action": "stop" })
}

resource "aws_cloudwatch_event_target" "start_ecs_target" {
  rule      = aws_cloudwatch_event_rule.start_ecs.name
  target_id = "start_ecs"
  arn       = aws_lambda_function.ecs_scheduler.arn
  input     = jsonencode({ "action": "start" })
}

resource "aws_lambda_permission" "allow_cloudwatch_stop" {
  statement_id  = "AllowExecutionFromCloudWatchStop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecs_scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_ecs.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_start" {
  statement_id  = "AllowExecutionFromCloudWatchStart"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecs_scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_ecs.arn
}
