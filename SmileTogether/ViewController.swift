//
//  ViewController.swift
//  SmileTogether
//
//  Created by user on 2021/06/09.
//

import Cocoa
import AVKit
import SwiftyJSON

func generateActionTrackID() -> String {
    var str = ""
    let rnd = "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    for _ in 0..<10 {
        str += String(rnd.randomElement()!)
    }
    str += "_\(Int(Date().timeIntervalSince1970 * 1000))"
    return str
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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        playerView.player = player
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func play(_ sender: Any) {
        let videoID = videoUrlField.stringValue
        async {
            do {
                try await play(videoID: videoID)
            } catch {
                print(error)
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

