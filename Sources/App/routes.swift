import FluentDynamoDB
import Foundation
import Vapor

enum EmergencyStopErrors: Error {
    case noUsername
}

let logger = PrintLogger()

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    router.get { req -> Future<View> in
        return try renderIndex(on: req)
    }

    router.post() { req -> Future<View> in
        let username = String(req.http.cookies["machine-cookie"]?.string.split(separator: ":").first ?? "debugging")
        logger.info("\(username) updating the lock")
        return try req.content.decode(Update.self).flatMap { update in
            return ServiceLock.read(on: req, serviceName: ServiceNames.global, version: 0).flatMap { latestLock in
                var lock = ServiceLock(serviceName: latestLock.serviceName, version: latestLock.currentVersion! + 1, currentVersion: nil, safeToProceed: update.safeToProceed, username: username, timestamp: Date(), message: update.message)
                return lock.write(on: req).flatMap { writtenOutput -> EventLoopFuture<View> in
                    lock.currentVersion = lock.version
                    lock.version = 0
                    return lock.write(on: req).flatMap { values -> EventLoopFuture<View> in
                        return try renderIndex(on: req)
                    }
                }
            }
        }
    }

    router.get("status") { req in
        print("Checking status")
        ServiceLock.read(on: req).map { lock -> String in
            logger.info("Status being retrieved")
            guard let response = try String(data: JSONEncoder().encode(lock), encoding: .utf8) else {
                logger.error("No lock retrieved")
                throw ServiceLock.LockError.noResponseError("No lock retrieved.")
            }
            return response
        }
    }

    router.get("health") { req in
        return "{\"status\": \"okay\"}"
    }
}

func renderIndex(on req: Request) throws -> Future<View> {
    return ServiceLock.read(on: req, serviceName: ServiceNames.global, version: 0).flatMap { latestLock in
        return try req.view().render("index", [
            "global": latestLock
        ])
    }
}

struct Update: Codable {
    public let message: String
    public let safeToProceed: Bool
}
