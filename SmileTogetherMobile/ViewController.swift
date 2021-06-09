//
//  ViewController.swift
//  SmileTogetherMobile
//
//  Created by user on 2021/06/09.
//

import UIKit
import AVKit
import GroupActivities
import Combine

class ViewController: UIViewController, VCProtocol {
    var redirector: MovieRedirector?
    
    var subscriptions = Set<AnyCancellable>()
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
    let player = AVPlayer()
    var playingNow: String = ""
    @IBOutlet weak var containerView: UIView!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        for vc in children {
            guard let vc = vc as? AVPlayerViewController else {
                continue
            }
            vc.player = player
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCheckSessions()
    }
    @IBAction func playNewVideo(_ sender: Any) {
        let alert = UIAlertController(title: "play", message: "please input video id", preferredStyle: .alert)
        alert.addTextField { textField in
            return
        }
        alert.addAction(.init(title: "OK", style: .default, handler: { _ in
            let videoID = alert.textFields![0].text!
            print(videoID)
            async {
                let activity = NicoVideoWatchingActivity(videoID: videoID)
                switch await activity.prepareForActivation() {
                case .activationDisabled:
                    self.playBackground(videoID: videoID)
                case .activationPreferred:
                    activity.activate()
                case .cancelled:
                    // nothing
                    break
                }
            }
        }))
        alert.addAction(.init(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func playBackground(videoID: String) {
        async {
            do {
                try await play(videoID: videoID)
            } catch {
                let alert = UIAlertController()
                alert.title = "play failed"
                alert.message = "\(error)"
                alert.addAction(.init(title: "OK", style: .default, handler: nil))
                present(alert, animated: true, completion: nil)
            }
        }
    }
}

