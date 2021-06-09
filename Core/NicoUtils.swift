//
//  NicoUtils.swift
//  SmileTogether
//
//  Created by user on 2021/06/09.
//

import Foundation
import SwiftyJSON

enum NicoUtils {
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:90.0) Gecko/20100101 Firefox/90.0"
    
    static func createDMCSessionParameters(dmcInfo: JSON) throws -> Data {
        let dmcSession = dmcInfo["movie"]["session"]
        let api = [
            "session": [
                "client_info": ["player_id": dmcSession["playerId"].stringValue],
                "content_auth": [
                    "auth_type": dmcSession["authTypes"]["http"].stringValue,
                    "content_key_timeout": dmcSession["contentKeyTimeout"].intValue,
                    "service_id": "nicovideo",
                    "service_user_id": dmcSession["serviceUserId"].stringValue,
                ],
                "content_id": dmcSession["contentId"].stringValue,
                "content_src_id_sets": [[
                    "content_src_ids": [[
                        "src_id_to_mux": [
                            "audio_src_ids": [dmcInfo["movie"]["audios"].arrayValue.filter({ $0["isAvailable"].boolValue }).sorted(by: {$0["metadata"]["bitrate"] > $1["metadata"]["bitrate"]}).first!["id"].stringValue],
                            "video_src_ids": [dmcInfo["movie"]["videos"].arrayValue.filter({ $0["isAvailable"].boolValue }).sorted(by: {$0["metadata"]["bitrate"] > $1["metadata"]["bitrate"]}).first!["id"].stringValue],
                        ]
                    ]]
                ]],
                "content_type": "movie",
                "content_uri": "",
                "keep_method": [
                    "heartbeat": ["lifetime": dmcSession["heartbeatLifetime"].intValue]
                ],
                "priority": dmcSession["priority"].doubleValue,
                "protocol": [
                    "name": "http",
                    "parameters": [
                        "http_parameters": [
                            "parameters": [
                                "http_output_download_parameters": [
                                    "transfer_preset": "",
                                    "use_ssl": "yes",
                                    "use_well_known_port": "yes",
                                ]
                            ]
                        ]
                    ]
                ],
                "recipe_id": dmcSession["recipeId"].stringValue,
                "session_operation_auth": [
                    "session_operation_auth_by_signature": [
                        "signature": dmcSession["signature"].stringValue,
                        "token": dmcSession["token"].stringValue,
                    ]
                ],
                "timing_constraint": "unlimited",
            ]
        ]
        return try JSONSerialization.data(withJSONObject: api, options: .prettyPrinted)
    }
    
    static func generateActionTrackID() -> String {
        var str = ""
        let rnd = "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        for _ in 0..<10 {
            str += String(rnd.randomElement()!)
        }
        str += "_\(Int(Date().timeIntervalSince1970 * 1000))"
        return str
    }
}
