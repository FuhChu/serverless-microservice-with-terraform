const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, ScanCommand } = require("@aws-sdk/lib-dynamodb");

// Initialize DynamoDB client
const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
    console.log("Received event:", JSON.stringify(event, null, 2));

    const tableName = process.env.TABLE_NAME; // Get table name from environment variable

    let response;
    try {
        switch (event.httpMethod) {
            case 'POST':
                // Parse the request body
                const body = JSON.parse(event.body);
                const itemToPut = { id: Date.now().toString(), ...body };

                // Put item into DynamoDB
                const putCommand = new PutCommand({
                    TableName: tableName,
                    Item: itemToPut
                });
                await docClient.send(putCommand);

                response = {
                    statusCode: 201,
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify(itemToPut)
                };
                break;

            case 'GET':
                // Scan DynamoDB table (for simplicity, in a real app use query for specific items)
                const scanCommand = new ScanCommand({
                    TableName: tableName
                });
                const { Items } = await docClient.send(scanCommand);

                response = {
                    statusCode: 200,
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify(Items)
                };
                break;

            default:
                response = {
                    statusCode: 405,
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({ message: "Method Not Allowed" })
                };
                break;
        }
    } catch (error) {
        console.error("Error:", error);
        response = {
            statusCode: 500,
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({ message: "Internal Server Error", error: error.message })
        };
    }

    // Add CORS headers for local testing or cross-origin access
    response.headers = {
        ...response.headers,
        "Access-Control-Allow-Origin": "*", // Allow all origins for simplicity
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type"
    };

    return response;
};