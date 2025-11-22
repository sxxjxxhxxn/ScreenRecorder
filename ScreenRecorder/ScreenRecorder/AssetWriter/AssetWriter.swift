//
//  AssetWriter.swift
//  ScreenRecorder
//
//  Created by jaehun on 11/17/25.
//

import Foundation
import AVFoundation
import ReplayKit

public final class AssetWriter {
    public enum MediaType {
        case audio
        case video
    }
    
    private(set) var mediaType: MediaType
    private var writer: AVAssetWriter? = nil
    private var writerInputs: [AVAssetWriterInput] = []
    
    private var isStartSession: Bool = false
    private var isWriting: Bool = false
    private(set) var isFinished: Bool = false {
        didSet {
            guard isFinished else { return }
            writer = nil
            writerInputs.removeAll()
        }
    }
    
    public init(mediaType: MediaType) {
        self.mediaType = mediaType
    }
    
    public func initialize() throws {
        try writer = AVAssetWriter(outputURL: URL(fileURLWithPath: mediaType.path), fileType: .mp4)
        
        isStartSession = false
        isFinished = false
        isWriting = false
        
        switch mediaType {
        case .video:
            setUpVideo()
        case .audio:
            setUpAudio()
        }
        
        writerInputs
            .filter({ writer?.canAdd($0) ?? false })
            .forEach({ writer?.add($0) })
    }
}
 
public extension AssetWriter {
    func cancel() {
        writer?.cancelWriting()
        isFinished = true
    }
    
    func clear() throws {
        guard FileManager.default.fileExists(atPath: mediaType.path) else { return }
        try FileManager.default.removeItem(atPath: mediaType.path)
    }
    
    func write(bufferType: RPSampleBufferType, buffer: CMSampleBuffer) {
        switch (mediaType, writer?.status) {
        case (_, .unknown):
            start()
        case (.video, _):
            writeVideo(buffer)
        case (.audio, _):
            writeAudio(bufferType, buffer)
        }
    }
    
    func finish(completion: @escaping () -> Void) {
        guard case .writing = writer?.status else {
            writer?.cancelWriting()
            isFinished = true
            completion()
            return
        }
        
        writerInputs.forEach({ $0.markAsFinished() })
        writer?.finishWriting { [weak self] in
            self?.isFinished = true
            completion()
        }
    }
}

private extension AssetWriter {
    private func start() {
        isWriting = writer?.startWriting() ?? false
    }
    
    private func setStartSessionIfNeeded(_ buffer: CMSampleBuffer) {
        guard isStartSession == false else { return }
        
        isStartSession = true
        writer?.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(buffer))
    }
    
    private func writeVideo(_ buffer: CMSampleBuffer) {
        guard isWriting else { return }
        setStartSessionIfNeeded(buffer)
        
        guard let writerInput = writerInputs.first, writerInput.isReadyForMoreMediaData else { return }
        writerInput.append(buffer)
    }
    
    private func writeAudio(_ bufferType: RPSampleBufferType, _ buffer: CMSampleBuffer) {
        guard isWriting else { return }
        setStartSessionIfNeeded(buffer)
        
        switch bufferType {
        case .audioApp where writerInputs.first?.isReadyForMoreMediaData ?== true:
            writerInputs.first?.append(buffer)
        case .audioMic where writerInputs.last?.isReadyForMoreMediaData ?== true:
            writerInputs.last?.append(buffer)
        default:
            break
        }
    }
    
    private func setUpVideo() {
        let writerInput = AVAssetWriterInput.newVideoWriterInput()
        writerInput.expectsMediaDataInRealTime = true
        writerInputs.append(writerInput)
    }
    
    private func setUpAudio() {
        let writerInputAudio = AVAssetWriterInput.newAudioWriterInput()
        writerInputAudio.expectsMediaDataInRealTime = true
        writerInputs.append(writerInputAudio)
        
        let writerInputMic = AVAssetWriterInput.newAudioWriterInput()
        writerInputMic.expectsMediaDataInRealTime = true
        writerInputs.append(writerInputMic)
    }
}

extension AssetWriter.MediaType {
    var path: String {
        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] as NSString
        return path.appendingPathComponent("\(String(describing: self)).mp4")
    }
    
    var avMediaType: AVMediaType {
        switch self {
        case .audio:
            return .audio
        case .video:
            return .video
        }
    }
}
