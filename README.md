# ScreenRecorder

**Screen Recording Service** iOS Example<br /> - Write and Merge **video & audio** asset sources

## APIs

```swift
class AssetWriterService {
    typealias Handler = ((Result<URL, AssetWriterError>) -> Void)?
    func write(buffer: CMSampleBuffer, bufferType: RPSampleBufferType, errorHandler: @escaping (AssetWriterError) -> Void)
    func finishWriting(completionHandler handler: Handler = nil)
}

class ScreenRecorder {
    func startRecord(isMicEnabled: Bool)
    func stopRecord()
}
```

## License

ScreenRecorder is under MIT license. See the [LICENSE](LICENSE) file for more info.

