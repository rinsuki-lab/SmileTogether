//
//  NicoVideoWatchingActivity.swift
//  SmileTogetherMobile
//
//  Created by user on 2021/06/09.
//

import Foundation
import GroupActivities

struct NicoVideoWatchingActivity: GroupActivity {
    static let activityIdentifier = "net.rinsuki.apps.SmileTogether.NicoVideoWatchingActivity"
    var videoID: String
    
    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.type = .watchTogether
        meta.title = videoID
        meta.fallbackURL = URL(string: "https://www.nicovideo.jp/watch/\(videoID)")
        return meta
    }
}
