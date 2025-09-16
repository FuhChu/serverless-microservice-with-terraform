# Serverless Microservice on AWS with Terraform

This project demonstrates how to build and deploy a simple, serverless RESTful microservice on AWS using Infrastructure as Code (IaC) with Terraform.

The microservice provides a basic CRUD-like API for managing "items" stored in a DynamoDB table.

## Core Technologies

*   **Terraform**: To define and provision all cloud infrastructure as code.
*   **AWS API Gateway**: To create, publish, and manage the RESTful API endpoint.
*   **AWS Lambda**: To run the backend application code without provisioning or managing servers.
*   **AWS DynamoDB**: To provide a fully managed, serverless NoSQL database with pay-per-request billing.
*   **AWS IAM**: To manage permissions and ensure secure access between services.
*   **Node.js**: As the runtime for the Lambda function.

---

## Architecture

The architecture is straightforward and follows a common serverless pattern:

```
Client (e.g., Browser, curl)
       │
       ▼
[API Gateway] --> ( /items endpoint with GET, POST methods)
       │
       ▼
[AWS Lambda]  --> (Node.js function processing the request)
       │
       ▼
[DynamoDB]    --> (Stores and retrieves item data)
```

---

## Prerequisites

Before you begin, ensure you have the following installed and configured:

1.  **Terraform CLI**: [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
2.  **AWS CLI**: [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
3.  **AWS Account & Credentials**: You must have an AWS account and your credentials configured for use by Terraform and the AWS CLI. You can do this by running `aws configure` or by setting environment variables.
    ```sh
    export AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_KEY"
    export AWS_REGION="us-east-1" # Or your preferred region
    ```

---

## Deployment

Follow these steps to deploy the entire infrastructure to your AWS account.

1.  **Clone the Repository**
    ```sh
    git clone <your-repository-url>
    cd serverless-microserviceP2
    ```

2.  **Initialize Terraform**
    This command initializes the working directory and downloads the necessary providers.
    ```sh
    terraform init
    ```

3.  **Plan the Deployment**
    This command creates an execution plan, showing you what resources Terraform will create, modify, or destroy. It's a great way to review changes before applying them.
    ```sh
    terraform plan
    ```

4.  **Apply the Configuration**
    This command applies the changes required to reach the desired state of the configuration.
    ```sh
    terraform apply --auto-approve
    ```
    After the apply is complete, Terraform will display the output variables, including the `api_gateway_endpoint`.

---

## Testing the API

Once deployed, you can test the API endpoint using a tool like `curl` or Postman. Use the `api_gateway_endpoint` value from the Terraform output.

### 1. Create an Item (POST)

Send a `POST` request to the `/items` endpoint with a JSON payload to create a new item.

```sh
# Replace <your-api-gateway-endpoint> with the actual URL from the terraform output
curl -X POST \
  '<your-api-gateway-endpoint>/items' \
  -H 'Content-Type: application/json' \
  -d '{"id": "item001", "name": "My First Test Item", "price": 29.99}'
```

You should receive a `200 OK` response confirming the item was created.

### 2. Get All Items (GET)

Send a `GET` request to the `/items` endpoint to retrieve all items from the DynamoDB table.

```sh
# Replace <your-api-gateway-endpoint> with the actual URL
curl '<your-api-gateway-endpoint>/items'
```

The response will be a JSON array containing the item(s) you created.

---

## Cleanup

To avoid incurring future charges, you can destroy all the resources created by this project with a single command.

```sh
terraform destroy --auto-approve
```