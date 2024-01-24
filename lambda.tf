resource "null_resource" "prepare_dist" {
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset("./lambda_function/src", "*"): filesha1("./lambda_function/src/${f}")]))
  }
  provisioner "local-exec" {
    command = "rm -rf ./tmp/lambda_dist_pkg && mkdir ./tmp/lambda_dist_pkg && cp -r ./lambda_function/lib64/python3.8/site-packages/* ./tmp/lambda_dist_pkg/ && cp -r ./lambda_function/src/* ./tmp/lambda_dist_pkg/"
  }
}

data "archive_file" "slack_fight_bot_lambda_package" {
  source_dir  = "${path.cwd}/tmp/lambda_dist_pkg"
  output_path = var.output_path
  type        = "zip"
  depends_on  = [null_resource.prepare_dist]
}

resource "aws_lambda_function" "slack_fight_bot_lambda" {
  function_name    = var.function_name
  filename         = data.archive_file.slack_fight_bot_lambda_package.output_path
  source_code_hash = data.archive_file.slack_fight_bot_lambda_package.output_base64sha256
  role             = aws_iam_role.slack_fight_bot_lambda_role.arn
  runtime          = var.runtime
  handler          = "lambda_handler.lambda_handler"
  timeout          = 10
}

resource "aws_cloudwatch_log_group" "slack_fight_lambda_log_group" {
  name              = "/aws/lambda/SlackFightBot"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_cloudwatch_event_rule" "slack_fight_bot_rate_event_rule" {
  name                = "slack-fight-bot-rate-event-rule"
  description         = "run on a set schedule"
  schedule_expression = "rate(3 minutes)"
}

resource "aws_cloudwatch_event_target" "slack_fight_bot_lambda_target" {
  arn  = aws_lambda_function.slack_fight_bot_lambda.arn
  rule = aws_cloudwatch_event_rule.slack_fight_bot_rate_event_rule.name
}

resource "aws_lambda_permission" "allow_cloudwatch_to_invoke_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_fight_bot_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.slack_fight_bot_rate_event_rule.arn
}

resource "aws_secretsmanager_secret" "slack_oauth_key" {
  name = "SlackFightBotOAuthKey"
}