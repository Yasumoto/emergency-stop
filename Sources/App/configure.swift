import DatabaseKit
import FluentDynamoDB
import Leaf
import Vapor

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
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

    // Note you MUST specify credentials via environment variables:
    // DYNAMO_ACCCESS_KEY: AWS Access Key to write to all tables you will use
    // DYNAMO_SECRET_KEY: Secret Key for the AWS user
    let dynamoAccessKey = Environment.get("DYNAMO_ACCCESS_KEY")
    let dynamoPrivateKey = Environment.get("DYNAMO_SECRET_KEY")
    let dynamoConfiguration = DynamoConfiguration(accessKeyId: dynamoAccessKey, secretAccessKey: dynamoPrivateKey)

    let dynamo = DynamoDatabase(config: dynamoConfiguration)
    databases.add(database: dynamo, as: .dynamo)
    services.register(databases)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    services.register(middlewares)
}
