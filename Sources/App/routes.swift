import FluentDynamoDB
import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    // "It works" page
    router.get { req -> Future<View> in
        let id = DatabaseIdentifier<DynamoDatabase>("dynamo")
        let dynamo = req.databaseConnection(to: id)
        let key = DynamoValue(attributes: ["key": DynamoValue.Attribute.string("value")])
        let query = DynamoQuery(action: .set, table: "fake-table", key: key)
        print("Trying to post the request, then rendering the response")
        return dynamo.flatMap { connection in
            return connection.query(query, { print($0) })
        }.flatMap { written in
            print(written)
            return try req.view().render("welcome")
        }
    }
    
    // Says hello
    router.get("hello", String.parameter) { req -> Future<View> in
        return try req.view().render("hello", [
            "name": req.parameters.next(String.self)
        ])
    }
}
