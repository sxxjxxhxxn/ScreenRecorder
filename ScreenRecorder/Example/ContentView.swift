//
//  ContentView.swift
//  ScreenRecorder
//
//  Created by jaehun on 11/17/25.
//

import SwiftUI
import Photos

struct ContentView: View {
    let recorder = ScreenRecorder()
    
    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Button {
                    recorder.startRecord(isMicEnabled: true)
                } label: {
                    Text("Start")
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(lineWidth: 1)
                        }
                }
                
                Button {
                    Task { @MainActor in
                        guard let result = try? await recorder.stopRecord() else { return }
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: result)
                        }) { saved, error in
                            print(saved, result)
                        }
                    }
                } label: {
                    Text("Stop")
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(lineWidth: 1)
                        }
                }
            }
        }
        .padding()
        .onAppear {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                switch status {
                case .notDetermined:
                    // 아직 사용자가 앱의 접근을 결정하지 않았음.
                    break
                case .restricted:
                    // 시스템이 앱의 접근을 제한함
                    break
                case .denied:
                    // 사용자가 명시적으로 앱의 접근을 거부함
                    break
                case .authorized:
                    // 사용자가 사진첩의 데이터에 접근을 허가함
                    break
                case .limited:
                    // 사용자가 사진첩의 접근을 허가하지만, 제한된 사진들만 가능.
                    break
                @unknown default:
                    fatalError()
                }
            }
        }
    }
}
