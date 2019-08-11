//
//  LoadtestInvocation.swift
//  
//
//  Created by Joe Smith on 7/16/19.
//

import Foundation

import FluentDynamoDB
import Vapor

public struct LoadtestInvocations: Codable {
    public enum DynamoTableNames: String {
        case prod = "limit-break-emergency-stop-invocations"
        case dev = "limit-break-emergency-stop-invocations-dev"
    }

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
        static let instanceID = "InstanceID"
    }

    public let username: String
    public let timestamp: Date
    public let hostname: String

    private static var formatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        return dateFormatter
    }

    public func dynamoFormat() -> DynamoValue {
        let attributes: [String: DynamoValue.Attribute] = [
            Fields.username: .string(self.username),
            Fields.timestamp: .string(LoadtestInvocations.formatter.string(from: self.timestamp)),
            Fields.hostname: .string(self.hostname)]
        return DynamoValue(attributes: attributes)
    }
}

extension LoadtestInvocations {
    public func write(on worker: Request) -> EventLoopFuture<[DynamoValue]> {
        let key = self.dynamoFormat()
        let query = DynamoQuery(action: .set, table: LoadtestInvocations.dynamoTable, keys: [key])
        return worker.databaseConnection(to: .dynamo).flatMap { connection in
            connection.query(query)
        }
    }

    public func readActive(on worker: Request) {

    }
}

extension LoadtestInvocations: Content { }
