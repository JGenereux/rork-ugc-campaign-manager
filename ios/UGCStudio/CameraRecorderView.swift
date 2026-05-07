import SwiftUI
import AVFoundation
import UIKit

@MainActor
@Observable
final class CameraRecorder: NSObject {
    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "ugc.camera.session")

    var isConfigured: Bool = false
    var isRecording: Bool = false
    var elapsed: TimeInterval = 0
    var permissionDenied: Bool = false
    var errorMessage: String?
    var lastRecordedURL: URL?
    var lastDuration: Double = 0

    private var startTime: Date?
    private var timer: Timer?
    private var continuation: CheckedContinuation<URL?, Never>?
    private var currentInput: AVCaptureDeviceInput?
    private var usingFront: Bool = false

    func requestAccessAndConfigure() async {
        let camStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let camGranted: Bool
        switch camStatus {
        case .authorized: camGranted = true
        case .notDetermined: camGranted = await AVCaptureDevice.requestAccess(for: .video)
        default: camGranted = false
        }
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let micGranted: Bool
        switch micStatus {
        case .authorized: micGranted = true
        case .notDetermined: micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        default: micGranted = false
        }
        guard camGranted, micGranted else {
            permissionDenied = true
            return
        }
        await configure()
    }

    private func configure() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                guard let self else { cont.resume(); return }
                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                // Reset
                for input in self.session.inputs { self.session.removeInput(input) }
                for output in self.session.outputs { self.session.removeOutput(output) }

                let position: AVCaptureDevice.Position = self.usingFront ? .front : .back
                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.currentInput = input
                }
                if let mic = AVCaptureDevice.default(for: .audio),
                   let micInput = try? AVCaptureDeviceInput(device: mic),
                   self.session.canAddInput(micInput) {
                    self.session.addInput(micInput)
                }
                if self.session.canAddOutput(self.movieOutput) {
                    self.session.addOutput(self.movieOutput)
                    if let conn = self.movieOutput.connection(with: .video), conn.isVideoStabilizationSupported {
                        conn.preferredVideoStabilizationMode = .auto
                    }
                }
                self.session.commitConfiguration()
                if !self.session.isRunning { self.session.startRunning() }
                Task { @MainActor in
                    self.isConfigured = true
                    cont.resume()
                }
            }
        }
    }

    func flip() {
        usingFront.toggle()
        Task { await configure() }
    }

    func startRecording() {
        guard isConfigured, !isRecording else { return }
        let url = URL.temporaryDirectory.appending(path: "take-\(UUID().uuidString).mov")
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
        isRecording = true
        startTime = Date()
        elapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let s = self.startTime else { return }
                self.elapsed = Date().timeIntervalSince(s)
            }
        }
    }

    @discardableResult
    func stopRecording() async -> URL? {
        guard isRecording else { return nil }
        return await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
            self.continuation = cont
            sessionQueue.async { [weak self] in
                self?.movieOutput.stopRecording()
            }
        }
    }

    func teardown() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
        }
        timer?.invalidate()
        timer = nil
    }
}

extension CameraRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        let url = outputFileURL
        let err = error
        Task { @MainActor in
            self.timer?.invalidate()
            self.timer = nil
            self.isRecording = false
            let duration = self.elapsed
            self.lastDuration = duration
            if let err {
                self.errorMessage = err.localizedDescription
                self.continuation?.resume(returning: nil)
            } else {
                self.lastRecordedURL = url
                self.continuation?.resume(returning: url)
            }
            self.continuation = nil
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
