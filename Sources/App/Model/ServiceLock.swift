//
//  ServiceLock.swift
//  App
//
//  Created by Joe Smith on 5/1/19.
//

import Vapor
import Foundation
import FluentDynamoDB

public struct ServiceNames {
    // Consider customization
    /// The table in DynamoDB to query in the account for data
    static let tableName = "limit-break-emergency-stop"

    /// Default namespace to track infrastructure-wide health
    static let global = "global"
}

struct ServiceLock: Codable {
    private struct Fields {
        static let serviceName = "ServiceName"
        static let version = "Version"
        static let currentVersion = "CurrentVersion"
        static let safeToProceed = "SafeToProceed"
        static let username = "Username"
        static let timestamp = "Timestamp"
        static let message = "Message"
    }

    public enum LockError: Error {
        case dynamoParseError(String)
        case noResponseError(String)
    }

    public let serviceName: String
    public var version: Int?
    public var currentVersion: Int?
    public let safeToProceed: Bool
    public let username: String
    public let timestamp: Date
    public let message: String
    private static var formatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        return dateFormatter
    }

    /// This requires and expects the currentVersion and version fields
    /// to be present.
    public func dynamoFormat() -> DynamoValue {
        var attributes: [String: DynamoValue.Attribute] = [
            Fields.serviceName: .string(serviceName),
            Fields.version: .number(String(version!)),
            Fields.safeToProceed: .bool(safeToProceed),
            Fields.username: .string(username),
            Fields.timestamp: .string(ServiceLock.formatter.string(from: timestamp)),
            Fields.message: .string(message)]
        if let currentVersion = self.currentVersion {
            attributes[Fields.currentVersion] = .number(String(currentVersion))
        }
        return DynamoValue(attributes: attributes)
    }
}

extension ServiceLock {
    public init(value: DynamoValue) throws {
        try self.init(attributes: value.attributes)
    }

    public init(attributes: [String: DynamoValue.Attribute]) throws {
        guard let serviceNameAttribute = attributes[Fields.serviceName], case .string(let serviceName) = serviceNameAttribute else {
            throw LockError.dynamoParseError("Could not pull out \(Fields.serviceName)")
        }
        self.serviceName = serviceName

        if let versionAttribute = attributes[Fields.version], case .number(let versionString) = versionAttribute, let version = Int(versionString) {
            self.version = version
        }

        if let currentVersionAttribute = attributes[Fields.currentVersion], case .number(let currentVersionString) = currentVersionAttribute, let currentVersion = Int(currentVersionString) {
            self.currentVersion = currentVersion
        }

        guard let safeToProceedAttribute = attributes[Fields.safeToProceed], case .bool(let safeToProceed) = safeToProceedAttribute else {
            throw LockError.dynamoParseError("Could not pull out \(Fields.safeToProceed)")
        }
        self.safeToProceed = safeToProceed

        guard let usernameAttribute = attributes[Fields.username], case .string(let username) = usernameAttribute else {
            throw LockError.dynamoParseError("Could not pull out \(Fields.username)")
        }
        self.username = username

        guard let timestampAttribute = attributes[Fields.timestamp], case .string(let timestampString) = timestampAttribute, let timestamp = ServiceLock.formatter.date(from: timestampString)  else {
            throw LockError.dynamoParseError("Could not pull out \(Fields.timestamp)")
        }
        self.timestamp = timestamp

        guard let messageAttribute = attributes[Fields.message], case .string(let message) = messageAttribute else {
            throw LockError.dynamoParseError("Could not pull out \(Fields.message)")
        }
        self.message = message
    }
}

extension ServiceLock {
    /// Write a ServiceLock to DynamoDB
    ///
    /// - Returns:
    ///     An `EventLoopFuture` used to indicate success or failure
    public func write(on worker: Request) -> EventLoopFuture<[DynamoValue]> {
        let key = self.dynamoFormat()
        let query = DynamoQuery(action: .set, table: ServiceNames.tableName, key: key)
        return worker.databaseConnection(to: .dynamo).flatMap { connection in
            connection.query(query)
        }
    }

    /// Retrieve a given version of the lock
    ///
    /// - Parameters:
    ///     - on: A worker to make the request on, typically a Vapor `Request`
    ///     - serviceName: Usually `global` but the namespace to query
    ///     - version: The specific version to pull down
    ///
    /// - Returns:
    ///     The desired lock value
    public static func read(on worker: Request, serviceName: String = ServiceNames.global, version: Int = 0) -> EventLoopFuture<ServiceLock> {
        let key = DynamoValue(attributes: [ServiceLock.Fields.serviceName: .string(serviceName), ServiceLock.Fields.version: .number(String(version))])
        let query = DynamoQuery(action: .get, table: ServiceNames.tableName, key: key)
        let queryResponse = worker.databaseConnection(to: .dynamo).flatMap { connection in
            return connection.query(query)
        }
        return queryResponse.map { (output: [DynamoDatabase.Output]) -> ServiceLock in
            if let value = output.first?.attributes {
                let lock = try ServiceLock(attributes: value)
                return lock
            }
            throw LockError.noResponseError("Unable to find lock for \(serviceName)")
        }
    }
}
