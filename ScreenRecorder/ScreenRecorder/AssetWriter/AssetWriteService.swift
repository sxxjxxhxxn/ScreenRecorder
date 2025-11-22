//
//  AssetWriteService.swift
//  ScreenRecorder
//
//  Created by jaehun on 11/17/25.
//

import Foundation
import ReplayKit

public final class AssetWriterService {
    public typealias Handler = ((Result<URL, AssetWriterError>) -> Void)?
    
    private let clipOutputString: String
    private var audioWriter = AssetWriter(mediaType: .audio)
    private var videoWriter = AssetWriter(mediaType: .video)
    private let writeQueue = DispatchQueue(label: "AssetWriterService.AssetWriterQueue")
    
    public init() {
        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] as NSString
        clipOutputString = path.appendingPathComponent("clip.mp4")
    }
    
    public func setUp() -> AssetWriterError? {
        if let error = removeCachedItems() {
            return error
        }
        
        do {
            try videoWriter.initialize()
            try audioWriter.initialize()
        } catch {
            return .setUpWriterError(error)
        }
        return nil
    }
    
    public func write(buffer: CMSampleBuffer, bufferType: RPSampleBufferType, errorHandler: @escaping (AssetWriterError) -> Void) {
        writeQueue.async { [weak self] in
            guard let videoWriter = self?.videoWriter,
                  let audioWriter = self?.audioWriter else {
                errorHandler(.setUpWriterError())
                return
            }
            
            switch bufferType {
            case .video:
                videoWriter.write(bufferType: bufferType, buffer: buffer)
            case .audioApp, .audioMic:
                audioWriter.write(bufferType: bufferType, buffer: buffer)
            default:
                break
            }
        }
    }
    
    public func cancelWriting() {
        videoWriter.cancel()
        audioWriter.cancel()
    }
    
    public func finishWriting(completionHandler handler: Handler = nil) {
        writeQueue.async { [weak self] in
            self?.videoWriter.finish { Task { await self?.completion(handler: handler) } }
            self?.audioWriter.finish { Task { await self?.completion(handler: handler) } }
        }
    }
    
    private func clipClear() throws {
        guard FileManager.default.fileExists(atPath: clipOutputString) else { return }
        try FileManager.default.removeItem(atPath: clipOutputString)
    }
    
    private func removeCachedItems() -> AssetWriterError? {
        do {
            try videoWriter.clear()
            try audioWriter.clear()
            try clipClear()
        } catch {
            return .removeCachedItems(error)
        }
        return nil
    }
    
    private func completion(handler: Handler) async {
        guard videoWriter.isFinished && audioWriter.isFinished else { return }
        guard handler != nil else { return }
        await mergeAndExport(handler: handler)
    }
    
    private func mergeComposition(_ composition: AVMutableComposition, writer: AssetWriter) async -> Result<Void, AssetWriterError> {
        let asset = AVAsset(url: URL(fileURLWithPath: writer.mediaType.path))
        let tracks = try? await asset.loadTracks(withMediaType: writer.mediaType.avMediaType)
        
        guard let tracks else { return .failure(.emptyTracks) }
        
        for track in tracks {
            let mutableTrack = composition.addMutableTrack(withMediaType: writer.mediaType.avMediaType,
                                                           preferredTrackID: kCMPersistentTrackID_Invalid)
            do {
                try await mutableTrack?.insertTimeRange(CMTimeRange(start: .zero, end: asset.load(.duration)),
                                                        of: track,
                                                        at: .zero)
            } catch {
                return .failure(.insertTimeRange(error))
            }
        }
        return .success(Void())
    }
    
    private func mergeAndExport(handler: Handler) async {
        let composition = AVMutableComposition()

        // merge video asset
        if case .failure(let error) = await mergeComposition(composition, writer: videoWriter) {
            handler?(.failure(error))
            return
        }
        // merge audio asset
        if case .failure(let error) = await mergeComposition(composition, writer: audioWriter) {
            handler?(.failure(error))
            return
        }
        
        // export
        let filePathURL = URL(fileURLWithPath: clipOutputString)
        guard let exportSession = AVAssetExportSession(asset: composition,
                                                       presetName: AVAssetExportPresetHighestQuality)
        else {
            handler?(.failure(.failedExportSession))
            return
        }
        
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.outputURL = filePathURL
        exportSession.exportAsynchronously { [weak exportSession] in
            switch exportSession?.error {
            case .none:
                handler?(.success(filePathURL))
            case .some(let error):
                handler?(.failure(.exportAsynchronously(error)))
            }
        }
    }
}

extension AssetWriterService {
    public enum AssetWriterError: Error {
        case insertTimeRange(Error)
        case exportAsynchronously(Error)
        case removeCachedItems(Error)
        case setUpWriterError(Error? = nil)
        case emptyTracks
        case failedExportSession
    }
}

extension AVAssetExportSession: @retroactive @unchecked Sendable { }
