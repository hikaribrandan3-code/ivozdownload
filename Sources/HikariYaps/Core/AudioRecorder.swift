import Foundation
import AVFoundation
import CoreAudio
import Accelerate

/// Captures microphone audio via AVAudioEngine and converts it to
/// 16 kHz mono Float32 samples (Whisper's expected input format).
final class AudioRecorder {
    static let targetSampleRate: Double = 16_000

    /// Called on the main thread with a smoothed 0...1 input level.
    var onLevel: ((Float) -> Void)?

    private var engine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private let samplesLock = NSLock()
    private var samples: [Float] = []
    private var smoothedLevel: Float = 0
    private(set) var isRecording = false
    private var startedAt: Date?

    var recordedDuration: TimeInterval {
        samplesLock.lock()
        defer { samplesLock.unlock() }
        return Double(samples.count) / Self.targetSampleRate
    }

    /// Starts capturing from the device with the given UID ("" = system default).
    func start(deviceUID: String) throws {
        guard !isRecording else { return }

        samplesLock.lock()
        samples.removeAll(keepingCapacity: true)
        samplesLock.unlock()
        smoothedLevel = 0

        let engine = AVAudioEngine()
        self.engine = engine
        let inputNode = engine.inputNode

        // Bind a specific input device if requested (default device otherwise).
        if !deviceUID.isEmpty,
           let device = deviceID(forUID: deviceUID),
           let audioUnit = inputNode.audioUnit {
            var deviceID = device
            AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &deviceID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
        }

        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw NSError(domain: "HikariYaps", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No audio input available. Check the selected microphone."
            ])
        }

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "HikariYaps", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Could not create target audio format."
            ])
        }

        converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer: buffer, targetFormat: targetFormat)
        }

        engine.prepare()
        try engine.start()
        isRecording = true
        startedAt = Date()
    }

    /// Stops capture and returns the recorded 16 kHz mono samples.
    @discardableResult
    func stop() -> [Float] {
        guard isRecording, let engine else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        converter = nil
        isRecording = false
        startedAt = nil

        samplesLock.lock()
        let result = samples
        samples.removeAll(keepingCapacity: false)
        samplesLock.unlock()

        DispatchQueue.main.async { [weak self] in self?.onLevel?(0) }
        return result
    }

    func cancel() {
        _ = stop()
    }

    // MARK: - Buffer processing (audio thread)

    private func process(buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        // Live level metering from the raw buffer.
        if let channelData = buffer.floatChannelData?[0] {
            var rms: Float = 0
            vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(buffer.frameLength))
            let db = 20 * log10(max(rms, 1e-7))
            let normalized = max(0, min(1, (db + 50) / 44))  // -50 dB..-6 dB → 0..1
            smoothedLevel = smoothedLevel * 0.6 + normalized * 0.4
            let level = smoothedLevel
            DispatchQueue.main.async { [weak self] in self?.onLevel?(level) }
        }

        guard let converter else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var consumed = false
        var error: NSError?
        converter.convert(to: converted, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard error == nil, converted.frameLength > 0, let channel = converted.floatChannelData?[0] else { return }

        let chunk = Array(UnsafeBufferPointer(start: channel, count: Int(converted.frameLength)))
        samplesLock.lock()
        samples.append(contentsOf: chunk)
        samplesLock.unlock()
    }

    // MARK: - Device lookup (CoreAudio, safe off main thread)

    private func deviceID(forUID uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize) == noErr else { return nil }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids) == noErr else { return nil }

        for id in ids {
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var size: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &uidAddress, 0, nil, &size) == noErr else { continue }
            var value: Unmanaged<CFString>?
            guard AudioObjectGetPropertyData(id, &uidAddress, 0, nil, &size, &value) == noErr,
                  let deviceUID = value?.takeRetainedValue() as String? else { continue }
            if deviceUID == uid { return id }
        }
        return nil
    }
}
