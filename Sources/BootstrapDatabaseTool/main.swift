/// This should be run on a local DynamoDB instance for testing
/// Kick it off first with
/// `docker run -p 8000:8000 amazon/dynamodb-local`
/// then run this script.

import DynamoDB

import Foundation

let isIncidentOngoing = false
let redButtonTableName: String
let invocationsTableName: String

let args = CommandLine.arguments
var path: String? = nil

if (args.contains("--help") || args.contains("-h")) {
    print("local-table-create [json_credentials_path]")
    print("JSON should contain two keys, ACCESS_KEY and SECRET_KEY")
    print("Built from https://github.com/Yasumoto/emergency-stop")
    exit(1)
}

if (args.count >= 2) {
    print("Please pass one path to a credentials file!")
    exit(1)
}

if (args.count == 2) {
    path = args[1]
}

struct AWSCreds: Codable {
    /// ACCCESS_KEY: AWS Access Key to write to the tables used by the application
    let accessKey: String?

    /// Secret/private Key for the AWS user
    let secretKey: String?

    enum CodingKeys: String, CodingKey {
        case accessKey = "ACCESS_KEY"
        case secretKey = "SECRET_KEY"
    }
}

let manager = FileManager.default
let dynamo: DynamoDB
if let path = path, manager.fileExists(atPath: path) {
    print("Searching for credentials at \(path)")

    guard let string = try? String(contentsOfFile: path), let data = string.data(using: .utf8) else {
        print("No valid credentials found at \(path)")
        exit(1)
    }
    guard let creds = try? JSONDecoder().decode(AWSCreds.self, from: data) else {
        print("Credentials malformed at \(path)")
        exit(1)
    }
    print("Found credentials in \(path)")
    dynamo = DynamoDB(accessKeyId: creds.accessKey, secretAccessKey: creds.secretKey)
    redButtonTableName = "limit-break-emergency-stop"
    invocationsTableName = "limit-break-emergency-stop-invocations"
} else {
    print("No credentials provided, assuming a local DynamoDB instance")
    dynamo = DynamoDB(accessKeyId: "test", secretAccessKey: "test", region: .useast1, endpoint: "http://localhost:8000")
    redButtonTableName = "limit-break-emergency-stop-dev"
    invocationsTableName = "limit-break-emergency-stop-invocations-dev"
}

let dynamoThroughput = DynamoDB.ProvisionedThroughput(readCapacityUnits: 10, writeCapacityUnits: 10)

let redButtonTableAttributes = [DynamoDB.AttributeDefinition(attributeName: "ServiceName", attributeType: .s),
                                DynamoDB.AttributeDefinition(attributeName: "Version", attributeType: .n)]

let redButtonKeySchema = [DynamoDB.KeySchemaElement(attributeName: "ServiceName", keyType: .hash),
                          DynamoDB.KeySchemaElement(attributeName: "Version", keyType: .range)]

do {
    let redButtonCreationInput = DynamoDB.CreateTableInput(attributeDefinitions: redButtonTableAttributes,
                                                           keySchema: redButtonKeySchema,
                                                           provisionedThroughput: dynamoThroughput,
                                                           tableName: redButtonTableName)
    let redButtonCreateResponse = try dynamo.createTable(redButtonCreationInput).wait()
    print(redButtonCreateResponse)
} catch {
    print("Error creating \(redButtonTableName): \(error)")
}

let invocationTableAttributes = [DynamoDB.AttributeDefinition(attributeName: "Hostname", attributeType: .s),
                                 DynamoDB.AttributeDefinition(attributeName: "Username", attributeType: .s),
                                 DynamoDB.AttributeDefinition(attributeName: "ServiceName", attributeType: .s),
                                 DynamoDB.AttributeDefinition(attributeName: "Timestamp", attributeType: .s)]

let invocationKeySchema = [DynamoDB.KeySchemaElement(attributeName: "Hostname", keyType: .hash),
                           DynamoDB.KeySchemaElement(attributeName: "Username", keyType: .range)]
let invocationGSI = DynamoDB.GlobalSecondaryIndex(indexName: "emergency_stop_timestamps_index",
                                                  keySchema: [
                                                    DynamoDB.KeySchemaElement(attributeName: "ServiceName", keyType: .hash),
                                                    DynamoDB.KeySchemaElement(attributeName: "Timestamp", keyType: .range)],
                                                  projection: DynamoDB.Projection(projectionType: .all),
                                                  provisionedThroughput: dynamoThroughput)

do {
    let invocationCreationInput = DynamoDB.CreateTableInput(attributeDefinitions: invocationTableAttributes,
                                                            globalSecondaryIndexes: [invocationGSI],
                                                            keySchema: invocationKeySchema,
                                                            provisionedThroughput: dynamoThroughput,
                                                            tableName: invocationsTableName)
    let invocationCreateResponse = try dynamo.createTable(invocationCreationInput).wait()
    print(invocationCreateResponse)
} catch {
    print("Error creating \(invocationsTableName): \(error)")
}

do {
    let listResponse = try dynamo.listTables(DynamoDB.ListTablesInput()).wait()
    if let names = listResponse.tableNames {
        for name in names {
            print(name)
        }
    }
} catch {
    print("Error trying to list tables: \(error)")
}

var formatter: DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    dateFormatter.timeZone = TimeZone(identifier: "UTC")
    return dateFormatter
}

for versionNumber in 1...4 {
    let value = DynamoDB.PutItemInput(item: ["ServiceName": DynamoDB.AttributeValue(s: "global"),
                                             "Version": DynamoDB.AttributeValue(n: String(versionNumber)),
                                             "IsIncidentOngoing": DynamoDB.AttributeValue(bool: isIncidentOngoing),
                                             "Username": DynamoDB.AttributeValue(s: "local-table-create"),
                                             "Timestamp": DynamoDB.AttributeValue(s: formatter.string(from: Date())),
                                             "Message": DynamoDB.AttributeValue(s: "Initial starting value from local-table-create tool")],
                                      returnValues: .allOld, tableName: redButtonTableName)

    let response = try dynamo.putItem(value).wait()
    print(response)
}


let currentValue = DynamoDB.PutItemInput(item: ["ServiceName": DynamoDB.AttributeValue(s: "global"),
                                             "Version": DynamoDB.AttributeValue(n: "0"),
                                             "CurrentVersion": DynamoDB.AttributeValue(n: "4"),
                                             "IsIncidentOngoing": DynamoDB.AttributeValue(bool: isIncidentOngoing),
                                             "Username": DynamoDB.AttributeValue(s: "local-table-create"),
                                             "Timestamp": DynamoDB.AttributeValue(s: formatter.string(from: Date())),
                                             "Message": DynamoDB.AttributeValue(s: "Initial starting value from local-table-create tool")],
                                      returnValues: .allOld, tableName: redButtonTableName)
let currentResponse = try dynamo.putItem(currentValue).wait()
print(currentResponse)

let scanResponse = try dynamo.scan(DynamoDB.ScanInput(tableName: redButtonTableName)).wait()
print(scanResponse)
