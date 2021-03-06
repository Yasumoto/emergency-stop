import FluentDynamoDB
import Foundation
import Vapor
import Prometheus
import Metrics

enum EmergencyStopErrors: Error {
    case noUsername
    case noHistory
    case malformedInvocation(String)
    case dynamoWriteError(String)
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

struct InvocationLabel: MetricLabels {
    init() {
        self.tool = ""
    }

    init(tool: String) {
        self.tool = tool
    }

    let tool: String
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
        let promClient = try req.make(PrometheusClient.self)

        let username = String(req.http.cookies["machine-cookie"]?.string.split(separator: ":").first ?? "debugging")
        logger.info("\(username) updating the lock")
        return try req.content.decode(Update.self).flatMap { update in
            return ServiceLock.read(on: req, serviceName: ServiceNames.global, version: 0).flatMap { latestLock in
                var lock = ServiceLock(serviceName: latestLock.serviceName, version: latestLock.currentVersion! + 1, currentVersion: nil, isIncidentOngoing: update.isIncidentOngoing, username: username, timestamp: Date(), message: update.message)
                return lock.write(on: req).flatMap { writtenOutput -> EventLoopFuture<View> in
                    promClient.createCounter(forType: Int.self, named: "lock_updates_total", withLabelType: UrlLabel.self).inc()
                    lock.currentVersion = lock.version
                    lock.version = 0
                    return lock.write(on: req).flatMap { values -> EventLoopFuture<View> in
                        return try renderIndex(on: req)
                    }
                }.thenIfErrorThrowing { error in
                    promClient.createCounter(forType: Int.self, named: "lock_write_errors_total", withLabelType: UrlLabel.self).inc()
                    throw error
                }
            }
        }
    }

    router.post(LoadtestInvocation.self, at: "register") { (req, invocation) -> EventLoopFuture<LoadtestInvocation> in
        let promClient = try req.make(PrometheusClient.self)
        promClient.createCounter(forType: Int.self, named: "invocation_register", withLabelType: InvocationLabel.self).inc(1, InvocationLabel(tool: invocation.loadtestToolName))

        var invocation = invocation
        invocation.timestamp = Date()
        return invocation.write(on: req)
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
    let promClient = try req.make(PrometheusClient.self)

    return ServiceLock.read(on: req, version: version).map { lock -> String in
        logger.info("Retrieved status of \(version) at \(Date())")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let response = try String(data: encoder.encode(lock), encoding: .utf8) else {
            logger.error("No lock retrieved for global/\(version)")
            promClient.createCounter(forType: Int.self, named: "lock_read_error").inc(1)
            throw ServiceLock.LockError.noResponseError("No lock retrieved.")
        }
        return response
    }
}

func renderIndex(on req: Request) throws -> Future<View> {
    let promClient = try req.make(PrometheusClient.self)

    let locks: EventLoopFuture<[ServiceLock]> = ServiceLock.read(on: req, serviceName: ServiceNames.global, version: 0).flatMap { (latestLock: ServiceLock) -> EventLoopFuture<[ServiceLock]> in
        guard let lastVersion = latestLock.currentVersion else {
            promClient.createCounter(forType: Int.self, named: "lock_read_error").inc(1)
            return req.future(error: EmergencyStopErrors.noHistory)
        }
        return ServiceLock.readRange(on: req, serviceName: ServiceNames.global, versions: max(0,   lastVersion-4)...lastVersion)
    }
    let invocations: EventLoopFuture<[LoadtestInvocation]> = LoadtestInvocation.readActive(on: req)
    return locks.and(invocations).flatMap{ (recentLocks: [ServiceLock], activeInvocations: [LoadtestInvocation]) -> Future<View> in
        let lockHistory = recentLocks.sorted(by: { $0.version! > $1.version! })
        return try req.view().render("index", IndexContext(activeInvocations: activeInvocations, latestLock: lockHistory.first!, lockHistory: lockHistory))
    }
}

struct IndexContext: Encodable {
    public let activeInvocations: [LoadtestInvocation]
    public let latestLock: ServiceLock
    public let lockHistory: [ServiceLock]
}

struct Update: Codable {
    public let message: String
    public let isIncidentOngoing: Bool
}
