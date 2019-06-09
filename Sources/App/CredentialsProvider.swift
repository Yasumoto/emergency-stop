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
    let logger = PrintLogger()
    let manager = FileManager.default
    logger.info("Searching for credentials at \(path)")
    if manager.fileExists(atPath: path) {
        if let string = try? String(contentsOfFile: path) {
            logger.info("ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_/abcdefghijklmnopqrstuvwxyz".reduce(string, { $0.replacingOccurrences(of: "\($1)", with: "*")}))
            if let data = string.data(using: .utf8) {
                if let creds = try? JSONDecoder().decode(AWSCreds.self, from: data) {
                    logger.info("Found credentials in \(path)")
                    return creds
                }
            }
        }
    } else if let accessKey = Environment.get("ACCCESS_KEY"), let secretKey = Environment.get("SECRET_KEY") {
        logger.info("Found credentials in the environment")
        return AWSCreds(accessKey: accessKey, secretKey: secretKey)
    }
    logger.info("No credentials found in \(path) or ENV variables.")
    return AWSCreds(accessKey: nil, secretKey: nil)
}
