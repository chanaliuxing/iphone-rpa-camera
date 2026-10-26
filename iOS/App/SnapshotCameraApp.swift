import SwiftUI
import AVFoundation
import Network
import UIKit

// iOS 15+; iPhone 7 Plus. LAN snapshot capture: no video encoding or streaming.
// All HTTP listener state and pending requests are owned by netQueue.

@main
struct SnapshotCameraApp: App {
    @StateObject private var camera = SnapshotBridge()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("RPA · Snapshot Camera").font(.title2.bold())
                    Text("Mac / Windows 每次请求才拍一张照片；不传视频")
                        .foregroundColor(.secondary).font(.subheadline)
                    SnapshotPreview(session: camera.session)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text("状态：\(camera.status)").font(.subheadline)
                    Text("端口：8080 | /shot.jpg | 后置主摄像头")
                        .font(.caption)
                    HStack {
                        Text("Token：\(camera.token)")
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(2)
                            .textSelection(.enabled)
                        Button("复制") { UIPasteboard.general.string = camera.token }
                    }
                    Button(camera.isRunning ? "停止" : "启动局域网拍照服务") {
                        camera.isRunning ? camera.stop() : camera.start()
                    }
                    .buttonStyle(.borderedProminent)
                    Text("让手机与 Mac / Windows 在同一个可信 Wi-Fi。到 iPhone 设置 → Wi-Fi 查看本机 IP；电脑使用 http://手机IP:8080/shot.jpg 定时请求。保持 App 前台、手机不锁屏，可插电。")
                        .font(.footnote).foregroundColor(.secondary)
                }
                .padding()
            }
            .onChange(of: scenePhase) { phase in
                if phase != .active { camera.stop() }
            }
        }
    }
}

final class PreviewLayerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct SnapshotPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewLayerView {
        let view = PreviewLayerView()
        view.backgroundColor = .black
        view.previewLayer.videoGravity = .resizeAspect
        view.previewLayer.session = session
        return view
    }
    func updateUIView(_ uiView: PreviewLayerView, context: Context) {}
}

final class SnapshotBridge: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published private(set) var status = "未启动"
    @Published private(set) var isRunning = false
    private var starting = false   // main queue only

    // Persist per installation, so the user copies the token only once.
    let token: String = {
        if let old = UserDefaults.standard.string(forKey: "rpa_snapshot_token"), !old.isEmpty {
            return old
        }
        let new = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        UserDefaults.standard.set(new, forKey: "rpa_snapshot_token")
        return new
    }()

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let cameraQueue = DispatchQueue(label: "rpa.snapshot.capture")
    private let netQueue = DispatchQueue(label: "rpa.snapshot.http")
    private var configured = false              // cameraQueue only
    private var listener: NWListener?            // netQueue only

    private struct Pending {
        let settingsId: Int64
        let conn: NWConnection
    }
    private var pending: Pending?                // netQueue only

    func start() {
        guard !starting && !isRunning else { return }
        starting = true
        status = "申请后置摄像头权限…"
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] accepted in
                DispatchQueue.main.async {
                    if accepted { self?.setupAndStart() }
                    else { self?.starting = false; self?.status = "相机权限被拒绝" }
                }
            }
        default:
            starting = false
            status = "请在设置中给本 App 摄像头权限"
        }
    }

    private func setupAndStart() {
        status = "初始化照片采集器…"
        cameraQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configureCamera()
                self.session.startRunning()
                self.netQueue.async { [weak self] in self?.startServer() }
            } catch {
                DispatchQueue.main.async {
                    self.starting = false
                    self.status = "启动失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func configureCamera() throws {
        if configured { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw NSError(domain: "Snapshot", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法找到后置主摄像头"])
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw NSError(domain: "Snapshot", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法添加摄像头输入"])
        }
        session.addInput(input)
        guard session.canAddOutput(output) else {
            throw NSError(domain: "Snapshot", code: 3, userInfo: [NSLocalizedDescriptionKey: "无法添加照片输出"])
        }
        session.addOutput(output)
        output.isHighResolutionCaptureEnabled = true
        configured = true
    }

    private func startServer() {
        // One token-protected LAN HTTP endpoint; no automatic video transfer.
        if listener != nil { return }
        do {
            let l = try NWListener(using: .tcp, on: 8080)
            l.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
            l.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    DispatchQueue.main.async {
                        self.starting = false
                        self.isRunning = true
                        self.status = "服务就绪：等待 Mac / Windows 拍照请求"
                        UIApplication.shared.isIdleTimerDisabled = true
                    }
                case .failed(let error):
                    self.listener?.cancel()
                    self.listener = nil
                    DispatchQueue.main.async {
                        self.starting = false
                        self.isRunning = false
                        self.status = "监听失败：\(error.localizedDescription)"
                        UIApplication.shared.isIdleTimerDisabled = false
                    }
                default: break
                }
            }
            listener = l
            l.start(queue: netQueue)
        } catch {
            DispatchQueue.main.async {
                self.starting = false
                self.status = "端口 8080 启动失败：\(error.localizedDescription)"
            }
        }
    }

    private func accept(_ conn: NWConnection) {
        conn.start(queue: netQueue)
        readHTTPHeader(conn, accumulated: Data())
    }

    private func readHTTPHeader(_ conn: NWConnection, accumulated: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { conn.cancel(); return }
            if error != nil { conn.cancel(); return }
            var buffer = accumulated
            if let data { buffer.append(data) }
            if buffer.count > 8192 {
                self.sendText(conn, code: "431 Request Header Fields Too Large", text: "Header too large")
                return
            }
            if buffer.range(of: Data("\r\n\r\n".utf8)) != nil {
                self.handleHTTP(conn, header: buffer)
            } else if !isComplete {
                self.readHTTPHeader(conn, accumulated: buffer)
            } else {
                conn.cancel()
            }
        }
    }

    private func handleHTTP(_ conn: NWConnection, header: Data) {
        guard let request = String(data: header, encoding: .utf8) else {
            sendText(conn, code: "400 Bad Request", text: "Bad HTTP header")
            return
        }
        let lines = request.components(separatedBy: "\r\n")
        guard let first = lines.first else {
            sendText(conn, code: "400 Bad Request", text: "Missing request line")
            return
        }
        let parts = first.split(separator: " ")
        guard parts.count == 3, parts[0] == "GET", parts[1] == "/shot.jpg" else {
            sendText(conn, code: "404 Not Found", text: "GET /shot.jpg only")
            return
        }
        let incomingToken = lines.dropFirst().first(where: {
            $0.lowercased().hasPrefix("x-rpa-token:")
        })?.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard incomingToken == token else {
            sendText(conn, code: "403 Forbidden", text: "Invalid token")
            return
        }
        guard pending == nil else {
            sendText(conn, code: "429 Too Many Requests", text: "Photo capture busy")
            return
        }
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        settings.isHighResolutionPhotoEnabled = true
        let id = settings.uniqueID
        pending = Pending(settingsId: id, conn: conn)

        // Never hang a connection forever if the device suspends or camera fails.
        netQueue.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, let current = self.pending, current.settingsId == id else { return }
            self.pending = nil
            self.sendText(current.conn, code: "504 Gateway Timeout", text: "Photo capture timed out")
        }
        cameraQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else {
                self.netQueue.async {
                    guard let current = self.pending, current.settingsId == id else { return }
                    self.pending = nil
                    self.sendText(current.conn, code: "503 Service Unavailable", text: "Camera not running")
                }
                return
            }
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let id = photo.resolvedSettings.uniqueID
        let jpeg = error == nil ? photo.fileDataRepresentation() : nil
        let capturedAt = ISO8601DateFormatter().string(from: Date())
        netQueue.async { [weak self] in
            guard let self, let current = self.pending, current.settingsId == id else { return }
            self.pending = nil
            guard let jpeg, jpeg.count >= 4,
                  jpeg.prefix(2) == Data([0xff, 0xd8]) else {
                self.sendText(current.conn, code: "500 Internal Server Error", text: "Photo encoding failed")
                return
            }
            let headers = [
                "HTTP/1.1 200 OK",
                "Content-Type: image/jpeg",
                "Content-Length: \(jpeg.count)",
                "Cache-Control: no-store",
                "X-Capture-Id: \(UUID().uuidString)",
                "X-Captured-At: \(capturedAt)",
                "Connection: close", "", ""
            ].joined(separator: "\r\n")
            self.send(current.conn, content: Data(headers.utf8) + jpeg)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        guard error != nil else { return }
        let id = resolvedSettings.uniqueID
        netQueue.async { [weak self] in
            guard let self, let current = self.pending, current.settingsId == id else { return }
            self.pending = nil
            self.sendText(current.conn, code: "500 Internal Server Error", text: "Camera photo capture failed")
        }
    }

    private func sendText(_ conn: NWConnection, code: String, text: String) {
        let body = Data(text.utf8)
        let head = "HTTP/1.1 \(code)\r\nContent-Type: text/plain\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
        send(conn, content: Data(head.utf8) + body)
    }

    private func send(_ conn: NWConnection, content: Data) {
        conn.send(content: content, completion: .contentProcessed { _ in conn.cancel() })
    }

    func stop() {
        netQueue.async { [weak self] in
            guard let self else { return }
            self.pending?.conn.cancel()
            self.pending = nil
            self.listener?.cancel()
            self.listener = nil
        }
        cameraQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
        }
        DispatchQueue.main.async {
            self.starting = false
            self.isRunning = false
            self.status = "已停止"
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
