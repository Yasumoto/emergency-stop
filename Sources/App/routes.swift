import FluentDynamoDB
import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    // TODO(jmsmith): Gotta be a better way to make this happen
    let tableName = Environment.get("DYNAMO_TABLE_NAME")!

    router.get { req -> Future<View> in
        let dynamo = req.databaseConnection(to: .dynamo)
        let key = DynamoValue(attributes: ["SafeToProceed": .string("lock")])
        let query = DynamoQuery(action: .get, table: tableName, key: key)
        return try req.view().render("index", [
            "safeToProceed": "\(true)"
            ])
        return dynamo.then { connection in
            return connection.query(query)
        }.flatMap { output in
            var attribute = "Safe to Proceed!"
            for value in output {
                for attributes in value.attributes {
                    attribute = "\(attributes.value)"
                }
            }
            return try req.view().render("index", [
                "safeToProceed": "\(attribute)"
                ])
        }
    }

    router.get("status") { req -> Future<String> in
        let key = DynamoValue(attributes: ["ServiceName": .string("global"), "Version": .number("0")])
        let query = DynamoQuery(action: .get, table: tableName, key: key)
        return req.databaseConnection(to: .dynamo).then { connection in
            return connection.query(query)
            }.map { "\($0)" }
    }
    
    router.post("lock") { req -> Future<String> in
        let key = DynamoValue(attributes: ["SafeToProceed": .string("lock")])
        let query = DynamoQuery(action: .set, table: tableName, key: key)
        return req.databaseConnection(to: .dynamo).then { connection in
            return connection.query(query)
        }.map { "\($0)" }
    }
}
