//
//  LoadtestInvocation.swift
//  
//
//  Created by Joe Smith on 7/16/19.
//

import Foundation

import FluentDynamoDB
import Vapor

//TODO(Yasumoto): Fix when FluentDynamoDB has proper support for queries
import DynamoDB

public struct LoadtestInvocation {
    public enum InvocationError: Error {
        case dynamoParseError(String)
    }

    public enum DynamoTableNames: String {
        case prod = "limit-break-emergency-stop-invocations"
        case dev = "limit-break-emergency-stop-invocations-dev"
    }

    static let TimeGSI = "emergency_stop_timestamps_index"

    static var dynamoTable: String {
        if let environment = Environment.get("ENVIRONMENT"), environment == "prod" {
            return DynamoTableNames.prod.rawValue
        }
        return DynamoTableNames.dev.rawValue
    }

    private struct Fields {
        static let username = "Username"
        static let timestamp = "Timestamp"
        static let hostname = "Hostname"
        static let loadtestToolName = "LoadtestToolName"
        static let serviceName = "ServiceName" // value always `global` for now
    }

    public let username: String
    public let timestamp: Date
    public let hostname: String
    public let loadtestToolName: String

    private static var formatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        return dateFormatter
    }

    public func dynamoFormat() -> DynamoValue {
        let attributes: [String: DynamoValue.Attribute] = [
            Fields.username: .string(self.username),
            Fields.timestamp: .string(LoadtestInvocation.formatter.string(from: self.timestamp)),
            Fields.hostname: .string(self.hostname),
            Fields.loadtestToolName: .string(self.loadtestToolName),
            Fields.serviceName: .string("global")
        ]
        return DynamoValue(attributes: attributes)
    }
}

extension LoadtestInvocation: Codable {
    enum CodingKeys: String, CodingKey {
        case username = "Username"
        case timestamp = "Timestamp"
        case hostname = "Hostname"
        case loadtestToolName = "LoadtestToolName"
    }
}

extension LoadtestInvocation {
    public init(value: DynamoValue) throws {
        try self.init(attributes: value.attributes)
    }

    public init(attributes: [String: DynamoValue.Attribute]) throws {
        guard let hostnameAttribute = attributes[Fields.hostname], case .string(let hostname) = hostnameAttribute else {
            throw InvocationError.dynamoParseError("Could not pull out \(Fields.hostname)")
        }
        self.hostname = hostname

        guard let usernameAttribute = attributes[Fields.username], case .string(let username) = usernameAttribute else {
            throw InvocationError.dynamoParseError("Could not pull out \(Fields.username)")
        }
        self.username = username

        guard let timestampAttribute = attributes[Fields.timestamp], case .string(let timestampString) = timestampAttribute, let timestamp = LoadtestInvocation.formatter.date(from: timestampString)  else {
            throw InvocationError.dynamoParseError("Could not pull out \(Fields.timestamp)")
        }
        self.timestamp = timestamp

        guard let loadtestToolNameAttribute = attributes[Fields.loadtestToolName], case .string(let loadtestToolName) = loadtestToolNameAttribute else {
            throw InvocationError.dynamoParseError("Could not pull out \(Fields.loadtestToolName)")
        }
        self.loadtestToolName = loadtestToolName
    }
}

extension LoadtestInvocation {
    public func write(on worker: Request) -> EventLoopFuture<LoadtestInvocation> {
        let key = self.dynamoFormat()
        let query = DynamoQuery(action: .set, table: LoadtestInvocation.dynamoTable, keys: [key])
        return worker.databaseConnection(to: .dynamo).flatMap { connection in
            connection.query(query).map { output in
                guard let value = output.first else {
                    throw InvocationError.dynamoParseError("No response when writing invocation")
                }
                return try LoadtestInvocation(value: value)
            }
        }
    }

    public static func readActive(on worker: Request, checkinMinutes: Int = 90) -> EventLoopFuture<[LoadtestInvocation]> {
        let now = Date()
        let earlier = now.addingTimeInterval(Double(-checkinMinutes) * 60.0)

        let expressionAttributeNames: [String: String]? = ["#S": Fields.serviceName, "#T": Fields.timestamp]
        let expressionAttributeValues: [String: DynamoDB.AttributeValue]? = [
            ":global": DynamoDB.AttributeValue(s: "global"),
            ":then": DynamoDB.AttributeValue(s: LoadtestInvocation.formatter.string(from: earlier)),
            ":now": DynamoDB.AttributeValue(s: LoadtestInvocation.formatter.string(from: now))]

        let keyConditionExpression = "#S = :global AND #T BETWEEN :then AND :now"
        let query = DynamoQuery(action: .filter, table: LoadtestInvocation.dynamoTable, keys: [DynamoValue](), index: LoadtestInvocation.TimeGSI, expressionAttributeNames: expressionAttributeNames, expressionAttributeValues: expressionAttributeValues, keyConditionExpression: keyConditionExpression)
        return worker.databaseConnection(to: .dynamo).flatMap { connection in
            connection.query(query).map { (output: [DynamoValue]) in
                return try output.map { try LoadtestInvocation(value: $0) }
            }
        }
    }
}

extension LoadtestInvocation: Content { }
