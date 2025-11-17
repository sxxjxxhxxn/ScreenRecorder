//
//  AVAssetWriterInput+Extension.swift
//  ScreenRecorder
//
//  Created by jaehun on 11/17/25.
//

import UIKit
import AVFoundation

extension AVAssetWriterInput {
    static func newVideoWriterInput() -> AVAssetWriterInput {
        let screen = UIScreen.current?.bounds ?? .zero
        let outputSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: floor(screen.width / 16) * 16,
            AVVideoHeightKey: floor(screen.height / 16) * 16,
        ] as [String: Any]
        return AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
    }
    
    static func newAudioWriterInput() -> AVAssetWriterInput {
        var channelLayout = AudioChannelLayout()
        channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_MPEG_2_0
        
        let outputSettings = [
            AVNumberOfChannelsKey: 2,
            AVFormatIDKey: kAudioFormatMPEG4AAC_HE,
            AVSampleRateKey: 44100,
            AVChannelLayoutKey: NSData(bytes: &channelLayout, length: MemoryLayout.size(ofValue: channelLayout))
        ] as [String: Any]
        return AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
    }
}

extension UIWindow {
    static var current: UIWindow? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                if window.isKeyWindow { return window }
            }
        }
        return nil
    }
}

extension UIScreen {
    static var current: UIScreen? {
        UIWindow.current?.screen
    }
}

infix operator ?== : ComparisonPrecedence
public func ?== <T: Equatable>(lhs: T?, rhs: T) -> Bool {
    if let lhs = lhs {
        return lhs == rhs
    }
    return false
}
