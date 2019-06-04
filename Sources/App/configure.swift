import DatabaseKit
import FluentDynamoDB
import Leaf
import Vapor

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    let logger = PrintLogger()

    // Register providers first
    try services.register(LeafProvider())

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)
    
    // Use Leaf for rendering views
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)

    // Bring in our database
    try services.register(FluentDynamoDBProvider())

    var databases = DatabasesConfig()

    let credentialsPath = Environment.get("CREDENTIALS_FILENAME") ?? "/etc/emergency-stop.json"
    logger.info("Searching for credentials at \(credentialsPath)")
    let creds = awsCredentials(path: credentialsPath)

    let dynamoConfiguration = DynamoConfiguration(accessKeyId: creds.accessKey, secretAccessKey: creds.secretKey)

    let dynamo = DynamoDatabase(config: dynamoConfiguration)
    databases.add(database: dynamo, as: .dynamo)
    services.register(databases)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    services.register(middlewares)
}
