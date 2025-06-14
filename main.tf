terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "ditto-sandbox1"
    key    = "terraform.tfstate"
    region = "ap-northeast-1"
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

# サンプルS3バケット
resource "aws_s3_bucket" "sandbox1" {
  bucket = "ditto-sandbox1-testbucket"
}

# Lambda関数用のIAMロール
resource "aws_iam_role" "lambda_role" {
  name = "sample-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda基本実行ポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}


# lambrollで作成されたLambda関数を参照
data "aws_lambda_function" "sample_function" {
  function_name = "sample-function"
}

# StepFunctions用のIAMロール
resource "aws_iam_role" "stepfunctions_role" {
  name = "sample-stepfunctions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# StepFunctionsがLambdaを呼び出すためのポリシー
resource "aws_iam_role_policy" "stepfunctions_lambda_policy" {
  name = "stepfunctions-lambda-policy"
  role = aws_iam_role.stepfunctions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = data.aws_lambda_function.sample_function.arn
      }
    ]
  })
}

# StepFunctions ステートマシン
resource "aws_sfn_state_machine" "sample_state_machine" {
  name     = "sample-state-machine"
  role_arn = aws_iam_role.stepfunctions_role.arn

  definition = jsonencode({
    Comment = "Sample state machine using lambroll-deployed Lambda"
    StartAt = "InvokeLambda"
    States = {
      InvokeLambda = {
        Type     = "Task"
        Resource = data.aws_lambda_function.sample_function.arn
        Parameters = {
          "message" = "Hello from StepFunctions!"
          "source"  = "stepfunctions"
        }
        Next = "ProcessResult"
      }
      ProcessResult = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.statusCode"
            NumericEquals = 200
            Next          = "Success"
          }
        ]
        Default = "Failure"
      }
      Success = {
        Type = "Pass"
        Result = {
          status  = "completed"
          message = "Lambda function executed successfully"
        }
        End = true
      }
      Failure = {
        Type  = "Fail"
        Cause = "Lambda function execution failed"
      }
    }
  })
}
