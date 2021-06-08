//
//  ViewController.swift
//  SmileTogether
//
//  Created by user on 2021/06/09.
//

import Cocoa
import AVKit
import SwiftyJSON
import GroupActivities
import Combine
import Regex

func generateActionTrackID() -> String {
    var str = ""
    let rnd = "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    for _ in 0..<10 {
        str += String(rnd.randomElement()!)
    }
    str += "_\(Int(Date().timeIntervalSince1970 * 1000))"
    return str
}

struct NicoVideoWatchingActivity: GroupActivity {
    var videoID: String
    
    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.type = .watchTogether
        meta.title = videoID
        meta.fallbackURL = URL(string: "https://www.nicovideo.jp/watch/\(videoID)")
        return meta
    }
}

class ViewController: NSViewController {
    @IBOutlet weak var videoUrlField: NSTextField!
    @IBOutlet weak var playerView: AVPlayerView!
    let player = AVPlayer()
    var heartbeatInfo: Task.Handle<Void, Error>? {
        didSet {
            if heartbeatInfo != oldValue {
                oldValue?.cancel()
            }
        }
    }
    var groupSession: GroupSession<NicoVideoWatchingActivity>? {
        didSet {
            guard let session = groupSession else {
                player.rate = 0
                return
            }
            player.playbackCoordinator.coordinateWithSession(session)
        }
    }
    var subscriptions = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        playerView.player = player
        
        async {
            for await groupSession in NicoVideoWatchingActivity.sessions() {
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

    @IBAction func play(_ sender: Any) {
        let includingVideoID = videoUrlField.stringValue
        guard
            let videoID = try? Regex(string: "((so|sm|nm)[0-9]+)").firstMatch(in: includingVideoID)?.captures.first,
            let videoID = videoID
        else {
            let alert = NSAlert()
            alert.informativeText = "Failed to find video id from input URL"
            alert.runModal()
            return
        }
        print(videoID)
        async {
            let activity = NicoVideoWatchingActivity(videoID: videoID)
            switch await activity.prepareForActivation() {
            case .activationDisabled:
                playBackground(videoID: videoID)
            case .activationPreferred:
                activity.activate()
            case .cancelled:
                // nothing
                break
            }
        }
    }
    
    func playBackground(videoID: String) {
        async {
            do {
                try await play(videoID: videoID)
            } catch {
                let alert = NSAlert()
                alert.informativeText = "play failed"
                alert.messageText = "\(error)"
            }
        }
    }
    
    func play(videoID: String) async throws {
        var watchAPIURL = URLComponents(string: "https://www.nicovideo.jp/api/watch/v3_guest/\(videoID)")!
        watchAPIURL.queryItems = [
            .init(name: "_frontendId", value: "6"),
            .init(name: "_frontendVersion", value: "0"),
            .init(name: "actionTrackId", value: generateActionTrackID()),
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
            let playerItem = AVPlayerItem(url: url)
            self.player.replaceCurrentItem(with: playerItem)
            self.player.play()
            let heartbeatLifetime = dmcInfo["movie"]["session"]["heartbeatLifetime"].intValue
            let heartbeatData = try dmcResponse["data"].rawData()
            self.heartbeatInfo = async {
                while true {
                    let lifeTime = UInt64(heartbeatLifetime) * 500 * 1000
                    print(lifeTime)
                    // ref. https://twitter.com/dgregor79/status/1402295472354562048
                    // TODO: remove after apple drops next beta?
                    await Task.sleep(lifeTime)
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

