//
//  ScreenRecorder.swift
//  ScreenRecorder
//
//  Created by jaehun on 11/17/25.
//

import UIKit
import ReplayKit
import Combine

final class ScreenRecorder: NSObject {
    enum State {
        case recording
        case done
    }
    
    private let recorder = RPScreenRecorder.shared()
    private let assetWriter = AssetWriterService()
    private var cancellable = Set<AnyCancellable>()
    
    @MainActor private(set) var state: State = .done
    var isRecording: Bool {
        recorder.isRecording
    }
    
    override init() {
        super.init()
        bind()
    }
    
    deinit {
        discard()
    }
    
    private func bind() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .filter { [weak self] _ in
                self?.state == .recording
            }
            .sink(receiveValue: { [weak self] _ in
                Task {
                    do {
                        _ = try await self?.stopRecord()
                    } catch(let error) {
                        debugPrint(error)
                    }
                }
            })
            .store(in: &cancellable)
        
        /// 레코더의 녹화가 중지되었는데 clipState가 recording으로 남아있다면 discard 처리함
        NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)
            .filter { _ in UIScreen.current?.traitCollection.sceneCaptureState == .inactive }
            .delay(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard self?.state == .recording else { return }
                self?.discard()
            }
            .store(in: &cancellable)
    }
    
    @MainActor
    func startRecord(isMicEnabled: Bool) {
        guard recorder.isAvailable,
              recorder.isRecording == false,
              state == .done else {
            discard()
            return
        }
        
        if let setUpError = assetWriter.setUp() {
            debugPrint(setUpError)
            discard()
            return
        }
        
        recorder.isMicrophoneEnabled = isMicEnabled
        recorder.startCapture { [weak self] buffer, bufferType, error in
            guard let self else {
                RPScreenRecorder.shared().stopCapture()
                return
            }
            
            if let error {
                debugPrint(error)
                return
            }
            
            // 간헐적으로 recording -> done -> recording 현상이 있음
            // 레코딩을 중지 했지만 잠깐 buffer가 내려오는 경우가 있어서 isRecording 상태를 확인하고 state를 변경하도록 수정
            if self.recorder.isRecording {
                self.state = .recording
            }
            
            self.assetWriter.write(buffer: buffer, bufferType: bufferType) { error in
                debugPrint(error)
            }
        }
    }
    
    @MainActor
    func stopRecord() async throws -> URL? {
        guard recorder.isRecording,
              state == .recording else {
            discard()
            throw ScreenRecorderError.stateError
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            recorder.stopCapture { [weak self] error in
                self?.state = .done
                
                if let error {
                    continuation.resume(throwing: error)
                }
                
                DispatchQueue.global(qos: .background).async {
                    self?.assetWriter.finishWriting { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            case .success(let fileURL):
                                continuation.resume(returning: fileURL)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func discard() {
        if recorder.isRecording {
            recorder.stopCapture()
            assetWriter.cancelWriting()
        }
        
        state = .done
    }
}

extension ScreenRecorder {
    public enum ScreenRecorderError: Error {
        case stateError
    }
}
