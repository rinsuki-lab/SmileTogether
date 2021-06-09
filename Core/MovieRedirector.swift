//
//  MovieRedirector.swift
//  SmileTogether
//
//  Created by user on 2021/06/09.
//

import Foundation
import AVFoundation

class MovieRedirector: NSObject, AVAssetResourceLoaderDelegate {
    var dest: URL
    init(dest: URL) {
        self.dest = dest
    }
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        loadingRequest.redirect = URLRequest(url: dest)
        loadingRequest.finishLoading()
        return true
    }
}
