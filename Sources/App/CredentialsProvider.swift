//
//  CredentialsProvider.swift
//  App
//
//  Created by Joe Smith on 6/3/19.
//

import Foundation
import Vapor

struct AWSCreds {
    /// DYNAMO_ACCCESS_KEY: AWS Access Key to write to all tables you will use
    let dynamoAccessKey: String

    /// DYNAMO_SECRET_KEY: Secret Key for the AWS user
    let dynamoPrivateKey: String
}

func awsCredentials(path: String) -> AWSCreds {
    let manager = FileManager.default

    if let contents = manager.enumerator(atPath: path) {
        let _ = contents.map { filename in
            print(filename)
        }
    } else if let dynamoAccessKey = Environment.get("DYNAMO_ACCCESS_KEY"), let dynamoPrivateKey = Environment.get("DYNAMO_SECRET_KEY") {
        return AWSCreds(dynamoAccessKey: dynamoAccessKey, dynamoPrivateKey: dynamoPrivateKey)
    }
    return AWSCreds(dynamoAccessKey: "", dynamoPrivateKey: "")
}
