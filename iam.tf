data "aws_iam_policy_document" "slack_fight_bot_lambda_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "function_logging_policy" {
  name = "function-logging-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_policy" "slack_fight_bot_secrets_access" {
  name = "slack-fight-bot-secrets-access"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : "secretsmanager:GetSecretValue",
        Effect : "Allow",
        Resource : aws_secretsmanager_secret.slack_oauth_key.arn
      }
    ]
  })
}

resource "aws_iam_role" "slack_fight_bot_lambda_role" {
  name               = "slack_fight_bot_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.slack_fight_bot_lambda_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "function_logging_policy_attachment" {
  role       = aws_iam_role.slack_fight_bot_lambda_role.id
  policy_arn = aws_iam_policy.function_logging_policy.arn
}

resource "aws_iam_role_policy_attachment" "slack_fight_bot_lambda_secrets_policy_attachment" {
  role       = aws_iam_role.slack_fight_bot_lambda_role.id
  policy_arn = aws_iam_policy.slack_fight_bot_secrets_access.arn
}