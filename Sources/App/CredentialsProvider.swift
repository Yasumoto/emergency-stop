//
//  CredentialsProvider.swift
//  App
//
//  Created by Joe Smith on 6/3/19.
//

import Foundation
import Vapor

struct AWSCreds: Codable {
    /// ACCCESS_KEY: AWS Access Key to write to the tables used by the application
    let accessKey: String?

    /// Secret/private Key for the AWS user
    let secretKey: String?

    enum CodingKeys: String, CodingKey {
        case accessKey = "ACCESS_KEY"
        case secretKey = "SECRET_KEY"
    }
}

func awsCredentials(path: String) -> AWSCreds {
    let manager = FileManager.default

    if manager.fileExists(atPath: path),
        let url = URL(string: path),
        let data = try? Data(contentsOf: url),
        let creds = try? JSONDecoder().decode(AWSCreds.self, from: data) {
            return creds
    } else if let accessKey = Environment.get("ACCCESS_KEY"), let secretKey = Environment.get("SECRET_KEY") {
        return AWSCreds(accessKey: accessKey, secretKey: secretKey)
    }
    return AWSCreds(accessKey: nil, secretKey: nil)
}
