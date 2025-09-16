output "api_gateway_endpoint" {
  description = "The invoke URL for the API Gateway endpoint."
  value       = aws_api_gateway_stage.api_stage.invoke_url
}

output "lambda_function_name" {
  description = "The name of the Lambda function."
  value       = aws_lambda_function.items_handler.function_name
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table."
  value       = aws_dynamodb_table.items_table.name
}