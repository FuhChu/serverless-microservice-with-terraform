# --- DynamoDB Table ---
resource "aws_dynamodb_table" "items_table" {
  name         = "${var.project_name}-items"
  billing_mode = "PAY_PER_REQUEST" # Serverless mode, no capacity units needed
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S" # String type for the hash key
  }

  tags = {
    Project = var.project_name
  }
}

#### 5.2. IAM Role for Lambda

#terraform
# --- IAM Role for Lambda ---
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Project = var.project_name
  }
}

# Policy for Lambda to write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy for Lambda to interact with DynamoDB
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "${var.project_name}-lambda-dynamodb-policy"
  description = "IAM policy for Lambda to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.items_table.arn
      }
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}


#### 5.3. Lambda Function


# --- Lambda Function ---

# Data source to package our Lambda code into a .zip file
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "items_handler" {
  function_name    = "${var.project_name}-items-handler"
  handler          = "index.handler" # file.function_name
  runtime          = "nodejs18.x"    # Or nodejs20.x if available and preferred
  role             = aws_iam_role.lambda_exec_role.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30 # seconds

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.items_table.name # Pass DynamoDB table name
    }
  }

  tags = {
    Project = var.project_name
  }
}


#### 5.4. API Gateway


# --- API Gateway ---

# 1. Create the REST API
resource "aws_api_gateway_rest_api" "rest_api" {
  name        = "${var.project_name}-api"
  description = "REST API for managing items"

  tags = {
    Project = var.project_name
  }
}

# 2. Create a Resource (e.g., '/items')
resource "aws_api_gateway_resource" "items_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "items" # This makes the path /items
}

# 3. Create a GET Method for /items
resource "aws_api_gateway_method" "get_items_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.items_resource.id
  http_method   = "GET"
  authorization = "NONE" # No authorization for simplicity
}

# 4. Integrate GET method with Lambda
resource "aws_api_gateway_integration" "get_items_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.items_resource.id
  http_method             = aws_api_gateway_method.get_items_method.http_method
  integration_http_method = "POST" # Lambda Proxy integration always uses POST
  type                    = "AWS_PROXY" # Lambda Proxy integration
  uri                     = aws_lambda_function.items_handler.invoke_arn
}

# 5. Create a POST Method for /items
resource "aws_api_gateway_method" "post_items_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.items_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# 6. Integrate POST method with Lambda
resource "aws_api_gateway_integration" "post_items_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.items_resource.id
  http_method             = aws_api_gateway_method.post_items_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.items_handler.invoke_arn
}

# 7. Create an OPTIONS method for CORS preflight (important for browser clients)
resource "aws_api_gateway_method" "options_items_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.items_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
  # This needs to be present for CORS preflight requests to succeed
  request_models = {
    "application/json" = "Error"
  }
  request_parameters = {
    "method.request.header.Access-Control-Request-Headers" = false,
    "method.request.header.Access-Control-Request-Method"  = false,
    "method.request.header.Origin"                         = false
  }
}

# 8. Set up the integration response for OPTIONS to handle CORS
resource "aws_api_gateway_integration" "options_items_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.items_resource.id
  http_method             = aws_api_gateway_method.options_items_method.http_method
  type                    = "MOCK" # MOCK integration is used for OPTIONS
  request_templates = {
    "application/json" = "{ \"statusCode\": 200 }"
  }
  connection_type = "INTERNET"
}

resource "aws_api_gateway_method_response" "options_items_200_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.items_resource.id
  http_method = aws_api_gateway_method.options_items_method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_items_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.items_resource.id
  http_method = aws_api_gateway_method.options_items_method.http_method
  status_code = aws_api_gateway_method_response.options_items_200_response.status_code
  response_templates = {
    "application/json" = ""
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [
    aws_api_gateway_method.options_items_method,
    aws_api_gateway_integration.options_items_integration
  ]
}


# 9. Deploy the API
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.get_items_integration,
    aws_api_gateway_integration.post_items_integration,
    aws_api_gateway_integration.options_items_integration # Ensure OPTIONS is deployed
  ]

  rest_api_id = aws_api_gateway_rest_api.rest_api.id

  # Note: This creates a new deployment every time `terraform apply` is run.
  # For production, you might want to manage deployments more carefully
  # (e.g., using a null_resource with triggers based on API changes).
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      # Ignore changes to the description to prevent unnecessary deployments
      # unless actual API changes occur. This is a common pattern.
      description
    ]
  }
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  stage_name    = "v1"
}

# 10. Grant API Gateway permission to invoke Lambda
resource "aws_lambda_permission" "apigw_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.items_handler.function_name
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion allows the Lambda function to be invoked by any method
  # on any resource under the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*"
}
