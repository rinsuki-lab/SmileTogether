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

class ViewController: NSViewController, VCProtocol {
    var redirector: MovieRedirector?
    
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
        startCheckSessions()
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
    
    var playingNow: String = ""
    
}

