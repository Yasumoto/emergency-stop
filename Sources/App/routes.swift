import FluentDynamoDB
import Foundation
import Vapor
import Prometheus
import Metrics

enum EmergencyStopErrors: Error {
    case noUsername
    case noHistory
}

struct UrlLabel: MetricLabels {
    init() {
        self.url = ""
    }

    init(url: String) {
        self.url = url
    }
    let url: String
}

//TODO(Yasumoto): Replace with SSWG's logger and properly inject during configuration
let logger = PrintLogger()

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    router.get { req -> Future<View> in
        logger.info("Rendering index")
        return try renderIndex(on: req)
    }

    router.post { req -> Future<View> in
        let username = String(req.http.cookies["machine-cookie"]?.string.split(separator: ":").first ?? "debugging")
        logger.info("\(username) updating the lock")
        return try req.content.decode(Update.self).flatMap { update in
            return ServiceLock.read(on: req, serviceName: ServiceNames.global, version: 0).flatMap { latestLock in
                var lock = ServiceLock(serviceName: latestLock.serviceName, version: latestLock.currentVersion! + 1, currentVersion: nil, isIncidentOngoing: update.isIncidentOngoing, username: username, timestamp: Date(), message: update.message)
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



    // Support more than just a global lock eventually
    router.get("status", "global", Int.parameter) { req -> EventLoopFuture<String> in
        let lockVersion = try req.parameters.next(Int.self)
        return try getLock(on: req, version: lockVersion)
    }

    router.get("status") { req -> EventLoopFuture<String> in
        return try getLock(on: req)
    }

    router.get("health") { req -> String in
        return "{\"health\": \"ok\"}"
    }
}

func getLock(on req: Request, version: Int = 0) throws -> EventLoopFuture<String> {
    logger.info("Checking status for global/\(version)")
    return ServiceLock.read(on: req, version: version).map { lock -> String in
        logger.info("Retrieved status of \(version) at \(Date())")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let response = try String(data: encoder.encode(lock), encoding: .utf8) else {
            logger.error("No lock retrieved for global/\(version)")
            do {
                let promClient = try req.make(PrometheusClient.self)
                promClient.createCounter(forType: Int.self, named: "lock_read_errors_total", withLabelType: UrlLabel.self).inc(1, UrlLabel(url: req.http.url.path))
            } catch {
                print("No prometheus client bootstrapped!")
            }
            throw ServiceLock.LockError.noResponseError("No lock retrieved.")
        }
        return response
    }
}

func renderIndex(on req: Request) throws -> Future<View> {
    return ServiceLock.read(on: req, serviceName: ServiceNames.global, version: 0).flatMap { latestLock in
        guard let lastVersion = latestLock.currentVersion else {
            do {
                let promClient = try req.make(PrometheusClient.self)
                promClient.createCounter(forType: Int.self, named: "lock_read_errors_total", withLabelType: UrlLabel.self).inc(1, UrlLabel(url: req.http.url.path))
            } catch {
                print("No prometheus client bootstrapped!")
            }
            return req.future(error: EmergencyStopErrors.noHistory)
        }
        return ServiceLock.readRange(on: req, serviceName: ServiceNames.global, versions: max(0,   lastVersion-4)...lastVersion).flatMap { (history: [ServiceLock]) -> Future<View> in
            return try req.view().render("index", IndexContext(latestLock: latestLock, history: history.sorted(by: { $0.version! > $1.version! })))
        }
    }
}

struct IndexContext: Encodable {
    public let latestLock: ServiceLock
    public let history: [ServiceLock]
}

struct Update: Codable {
    public let message: String
    public let isIncidentOngoing: Bool
}
