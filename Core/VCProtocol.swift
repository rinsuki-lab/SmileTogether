//
//  VCProtocol.swift
//  SmileTogetherMobile
//
//  Created by user on 2021/06/09.
//

import Foundation
import SwiftyJSON
import AVKit
import GroupActivities
import Combine

protocol VCProtocol: AnyObject {
    var groupSession: GroupSession<NicoVideoWatchingActivity>? { get set }
    var subscriptions: Set<AnyCancellable> { get set }
    var heartbeatInfo: Task.Handle<Void, Error>? { get set }
    var player: AVPlayer { get }
    var playingNow: String { get set }
    var redirector: MovieRedirector? { get set }
    
    func playBackground(videoID: String)
}

extension VCProtocol {
    func startCheckSessions() {
        print("a")
        async {
            print("b")
            for await groupSession in NicoVideoWatchingActivity.sessions() {
                print("c")
                self.groupSession = groupSession
                subscriptions.removeAll()
                groupSession.$state.sink { [weak self] state in
                    if case .invalidated = state {
                        self?.groupSession = nil
                        self?.subscriptions.removeAll()
                    }
                    print(state)
                }.store(in: &subscriptions)
                
                groupSession.join()
                groupSession.$activity.sink { [weak self] activity in
                    self?.playBackground(videoID: activity.videoID)
                }.store(in: &subscriptions)
            }
        }
    }
    
    func play(videoID: String) async throws {
        if playingNow == videoID {
            return
        }
        playingNow = videoID
        var watchAPIURL = URLComponents(string: "https://www.nicovideo.jp/api/watch/v3_guest/\(videoID)")!
        watchAPIURL.queryItems = [
            .init(name: "_frontendId", value: "6"),
            .init(name: "_frontendVersion", value: "0"),
            .init(name: "actionTrackId", value: NicoUtils.generateActionTrackID()),
            .init(name: "skips", value: "harmful"),
        ]
        print(watchAPIURL.url!)
        var watchAPIRequest = URLRequest(url: watchAPIURL.url!)
        watchAPIRequest.setValue(NicoUtils.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, res) = try await URLSession.shared.data(for: watchAPIRequest)
        let json = try JSON(data: data)
        print(json)
        let dmcInfo = json["data"]["media"]["delivery"]
        guard dmcInfo.exists() else {
            return
        }
        var dmcRequest = URLRequest(url: URL(string: "https://api.dmc.nico/api/sessions?_format=json")!)
        dmcRequest.httpMethod = "POST"
        dmcRequest.setValue(NicoUtils.userAgent, forHTTPHeaderField: "User-Agent")
        dmcRequest.httpBody = try NicoUtils.createDMCSessionParameters(dmcInfo: dmcInfo)
        let (dmcResponseRaw, _) = try await URLSession.shared.data(for: dmcRequest)
        let dmcResponse = try JSON(data: dmcResponseRaw)
        print(dmcResponse)
        if let url = dmcResponse["data"]["session"]["content_uri"].url {
            let redirector = MovieRedirector(dest: url)
            let asset = AVURLAsset(url: URL(string: "smiletogether://redirect.\(videoID).mp4")!)
            asset.resourceLoader.setDelegate(redirector, queue: .global())
            self.redirector = redirector
            let playerItem = AVPlayerItem(asset: asset)
            DispatchQueue.main.async {
                self.player.replaceCurrentItem(with: playerItem)
            }
            let heartbeatLifetime = dmcInfo["movie"]["session"]["heartbeatLifetime"].intValue
            let heartbeatData = try dmcResponse["data"].rawData()
            self.heartbeatInfo = asyncDetached(priority: .background) {
                while true {
                    let lifeTime = UInt32(heartbeatLifetime) / 2 / 1000
                    print(lifeTime)
                    // ref. https://twitter.com/dgregor79/status/1402295472354562048
                    // TODO: use Task.sleep after apple drops next beta
                    sleep(lifeTime)
                    print("checking...")
                    try Task.checkCancellation()
                    var req = URLRequest(url: URL(string: "https://api.dmc.nico/api/sessions/\(dmcResponse["data"]["session"]["id"].stringValue)?_format=json&_method=PUT")!)
                    req.httpMethod = "POST"
                    req.httpBody = heartbeatData
                    req.setValue(NicoUtils.userAgent, forHTTPHeaderField: "User-Agent")
                    let (res, _) = try await URLSession.shared.data(for: req)
                    print("heartbeat", String(data: res, encoding: .utf8))
                }
            }
        } else {
            print("fail...")
        }
    }
}
