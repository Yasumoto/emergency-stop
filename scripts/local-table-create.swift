#!/usr/bin/swift sh

/// This should be run on a local DynamoDB instance for testing
/// Kick it off first with
/// `docker run -p 8000:8000 amazon/dynamodb-local`
/// then run this script.

import DynamoDB // /Users/jmsmith/workspace/github.com/swift-aws/aws-sdk-swift

import Foundation

let path = "/Users/jmsmith/Desktop/aws.json"
let safeToProceed = false
let tableName = "limit-break-emergency-stop"

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
print("Searching for credentials at \(path)")
let dynamo: DynamoDB
if manager.fileExists(atPath: path) {
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
} else {
    dynamo = DynamoDB(accessKeyId: "test", secretAccessKey: "test", region: .useast1, endpoint: "http://localhost:8000")
}

let tableAttributes = [DynamoDB.AttributeDefinition(attributeName: "ServiceName", attributeType: .s),
                       DynamoDB.AttributeDefinition(attributeName: "Version", attributeType: .n)]

let keySchema = [DynamoDB.KeySchemaElement(attributeName: "ServiceName", keyType: .hash),
                 DynamoDB.KeySchemaElement(attributeName: "Version", keyType: .range)]

do {
    let creationInput = DynamoDB.CreateTableInput(attributeDefinitions: tableAttributes,  keySchema: keySchema, provisionedThroughput: DynamoDB.ProvisionedThroughput(readCapacityUnits: 10, writeCapacityUnits: 10), tableName: tableName)
    let createResponse = try dynamo.createTable(creationInput).wait()
    print(createResponse)
} catch {
    print("Table already exists!")
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

let currentValue = DynamoDB.PutItemInput(item: ["ServiceName": DynamoDB.AttributeValue(s: "global"),
                                             "Version": DynamoDB.AttributeValue(n: "0"),
                                             "CurrentVersion": DynamoDB.AttributeValue(n: "1"),
                                             "SafeToProceed": DynamoDB.AttributeValue(bool: safeToProceed),
                                             "Username": DynamoDB.AttributeValue(s: "local-table-create"),
                                             "Timestamp": DynamoDB.AttributeValue(s: formatter.string(from: Date())),
                                             "Message": DynamoDB.AttributeValue(s: "Initial starting value from local-table-create tool")],
                                      returnValues: .allOld, tableName: tableName)
let firstValue = DynamoDB.PutItemInput(item: ["ServiceName": DynamoDB.AttributeValue(s: "global"),
                                             "Version": DynamoDB.AttributeValue(n: "1"),
                                             "SafeToProceed": DynamoDB.AttributeValue(bool: safeToProceed),
                                             "Username": DynamoDB.AttributeValue(s: "local-table-create"),
                                             "Timestamp": DynamoDB.AttributeValue(s: formatter.string(from: Date())),
                                             "Message": DynamoDB.AttributeValue(s: "Initial starting value from local-table-create tool")],
                                      returnValues: .allOld, tableName: tableName)
let currentResponse = try dynamo.putItem(currentValue).wait()
print(currentResponse)
let firstResponse = try dynamo.putItem(firstValue).wait()
print(firstResponse)

let scanResponse = try dynamo.scan(DynamoDB.ScanInput(tableName: tableName)).wait()
print(scanResponse)
