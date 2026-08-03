// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import AppKit
import Combine
import Network
import Sparkle

struct UpdateFeedLocator: Sendable {
    static func validatedURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        guard url.scheme == "https" || url.isFileURL else { return nil }
        return url
    }

    static func bundledURL(bundle: Bundle = .main) -> URL? {
        guard let value = bundle.object(forInfoDictionaryKey: "KeptUpdateFeedURL") as? String else { return nil }
        return validatedURL(value)
    }

    static func localURL(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "com.kavaju.kept/Updates/appcast.xml")
    }

    static func resolvedActiveURL(
        selectedURL: URL?,
        servedLocalFeedURL: URL?,
        currentURL: URL?
    ) -> URL? {
        if selectedURL?.isFileURL == true,
           selectedURL == servedLocalFeedURL,
           currentURL?.host == "127.0.0.1" {
            return currentURL
        }
        return selectedURL
    }
}

private enum LocalUpdateServerError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "No se pudo iniciar el canal local de actualizaciones."
    }
}

/// Exposes the private update directory only on this Mac's loopback interface.
/// Sparkle intentionally refuses file:// feeds, so the personal workflow uses
/// a small HTTP endpoint without opening the directory to the local network.
final class LocalUpdateHTTPServer: @unchecked Sendable {
    private let rootDirectory: URL
    private let queue = DispatchQueue(label: "com.kavaju.kept.update-server")
    private var listener: NWListener?
    private var completion: (@Sendable (Result<URL, Error>) -> Void)?

    init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory.standardizedFileURL
    }

    func start(completion: @escaping @Sendable (Result<URL, Error>) -> Void) {
        queue.async { [self] in
            guard listener == nil else { return }
            self.completion = completion

            do {
                let parameters = NWParameters.tcp
                parameters.acceptLocalOnly = true
                parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
                let listener = try NWListener(using: parameters, on: .any)
                self.listener = listener
                listener.newConnectionHandler = { [weak self] connection in
                    self?.serve(connection)
                }
                listener.stateUpdateHandler = { [weak self] state in
                    self?.handle(state)
                }
                listener.start(queue: queue)
            } catch {
                finish(.failure(error))
            }
        }
    }

    func stop() {
        queue.async { [self] in
            listener?.cancel()
            listener = nil
            completion = nil
        }
    }

    private func handle(_ state: NWListener.State) {
        switch state {
        case .ready:
            guard let port = listener?.port,
                  let url = URL(string: "http://127.0.0.1:\(port.rawValue)/appcast.xml") else {
                finish(.failure(LocalUpdateServerError.unavailable))
                return
            }
            finish(.success(url))
        case .failed(let error):
            finish(.failure(error))
            listener?.cancel()
            listener = nil
        default:
            break
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        let callback = completion
        completion = nil
        callback?(result)
    }

    private func serve(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            if case .ready = state {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, _ in
                    self?.respond(to: data, on: connection)
                }
            }
        }
        connection.start(queue: queue)
    }

    private func respond(to requestData: Data?, on connection: NWConnection) {
        guard let requestData,
              let request = String(data: requestData, encoding: .utf8),
              let firstLine = request.components(separatedBy: "\r\n").first else {
            send(status: "400 Bad Request", body: Data(), mimeType: "text/plain", on: connection)
            return
        }

        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" || parts[0] == "HEAD" else {
            send(status: "405 Method Not Allowed", body: Data(), mimeType: "text/plain", on: connection)
            return
        }

        let rawPath = String(parts[1]).split(separator: "?", maxSplits: 1).first.map(String.init) ?? ""
        let filename = rawPath.removingPercentEncoding?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        let allowedExtensions = Set(["xml", "zip", "delta", "md", "html", "txt"])
        guard !filename.isEmpty,
              !filename.contains("/"),
              !filename.contains("\\"),
              allowedExtensions.contains((filename as NSString).pathExtension.lowercased()) else {
            send(status: "404 Not Found", body: Data(), mimeType: "text/plain", on: connection)
            return
        }

        let fileURL = rootDirectory.appending(path: filename).standardizedFileURL
        guard fileURL.deletingLastPathComponent() == rootDirectory,
              let body = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {
            send(status: "404 Not Found", body: Data(), mimeType: "text/plain", on: connection)
            return
        }

        let responseBody = parts[0] == "HEAD" ? Data() : body
        send(
            status: "200 OK",
            body: responseBody,
            contentLength: body.count,
            mimeType: mimeType(for: fileURL.pathExtension),
            on: connection
        )
    }

    private func mimeType(for extensionName: String) -> String {
        switch extensionName.lowercased() {
        case "xml": "application/rss+xml"
        case "zip", "delta": "application/octet-stream"
        case "html": "text/html; charset=utf-8"
        default: "text/plain; charset=utf-8"
        }
    }

    private func send(
        status: String,
        body: Data,
        contentLength: Int? = nil,
        mimeType: String,
        on connection: NWConnection
    ) {
        let header = "HTTP/1.1 \(status)\r\nContent-Length: \(contentLength ?? body.count)\r\nContent-Type: \(mimeType)\r\nConnection: close\r\nCache-Control: no-cache\r\n\r\n"
        var response = Data(header.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

@MainActor
final class UpdateService: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateService()

    @Published private(set) var isConfigured = false
    @Published private(set) var activeFeedURL: URL?
    @Published private(set) var customFeedURLString = ""
    @Published private(set) var configurationError: String?
    private(set) var isRelaunchingForUpdate = false

    private let defaults = UserDefaults.standard
    private let customFeedKey = "customUpdateFeedURL"
    private var started = false
    private var localServer: LocalUpdateHTTPServer?
    private var localFeedSource: URL?
    private var servedLocalFeedSource: URL?
    private var pendingManualCheck = false

    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    var updater: SPUUpdater { updaterController.updater }
    var allowsCustomFeed: Bool { UpdateFeedLocator.bundledURL() == nil }
    var canCheckForUpdates: Bool { isConfigured && updater.canCheckForUpdates }

    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set {
            updater.automaticallyChecksForUpdates = newValue
            objectWillChange.send()
        }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { updater.automaticallyDownloadsUpdates }
        set {
            updater.automaticallyDownloadsUpdates = newValue
            objectWillChange.send()
        }
    }

    override private init() {
        super.init()
        customFeedURLString = defaults.string(forKey: customFeedKey) ?? ""
        refreshConfiguration()
    }

    func start() {
        guard !started else { return }
        refreshConfiguration()
        guard isConfigured else { return }

        if let localFeedSource {
            guard localServer == nil else { return }
            startLocalServer(for: localFeedSource)
        } else {
            startUpdaterIfNeeded()
        }
    }

    func checkForUpdates() {
        if started {
            updater.checkForUpdates()
            return
        }
        pendingManualCheck = true
        start()
    }

    @discardableResult
    func setCustomFeedURL(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: customFeedKey)
            customFeedURLString = ""
            configurationError = nil
        } else {
            guard let url = UpdateFeedLocator.validatedURL(trimmed) else {
                configurationError = "Usa una URL HTTPS o un appcast local válido."
                return false
            }
            if url.isFileURL, !FileManager.default.fileExists(atPath: url.path) {
                configurationError = "No se encontró el archivo appcast seleccionado."
                return false
            }
            defaults.set(url.absoluteString, forKey: customFeedKey)
            customFeedURLString = url.absoluteString
            configurationError = nil
        }

        refreshConfiguration()
        if started {
            if let localFeedSource, servedLocalFeedSource != localFeedSource {
                startLocalServer(for: localFeedSource)
            } else {
                if localFeedSource == nil {
                    localServer?.stop()
                    localServer = nil
                    servedLocalFeedSource = nil
                }
                updater.resetUpdateCycle()
            }
        } else {
            localServer?.stop()
            localServer = nil
            servedLocalFeedSource = nil
            start()
        }
        return true
    }

    func refreshConfiguration() {
        let bundled = UpdateFeedLocator.bundledURL()
        let custom = allowsCustomFeed ? UpdateFeedLocator.validatedURL(customFeedURLString) : nil
        let local = UpdateFeedLocator.localURL()
        let localExists = FileManager.default.fileExists(atPath: local.path)
        let selected = bundled ?? custom ?? (localExists ? local : nil)
        localFeedSource = selected?.isFileURL == true ? selected : nil
        activeFeedURL = UpdateFeedLocator.resolvedActiveURL(
            selectedURL: selected,
            servedLocalFeedURL: servedLocalFeedSource,
            currentURL: activeFeedURL
        )
        isConfigured = activeFeedURL != nil
    }

    private func startLocalServer(for source: URL) {
        localServer?.stop()
        servedLocalFeedSource = nil

        let server = LocalUpdateHTTPServer(rootDirectory: source.deletingLastPathComponent())
        localServer = server
        server.start { [weak self] result in
            Task { @MainActor in
                guard let self, self.localFeedSource == source else { return }
                switch result {
                case .success(let url):
                    self.servedLocalFeedSource = source
                    self.activeFeedURL = url
                    if self.started {
                        self.updater.resetUpdateCycle()
                    } else {
                        self.startUpdaterIfNeeded()
                    }
                case .failure(let error):
                    self.localServer = nil
                    self.isConfigured = false
                    self.configurationError = error.localizedDescription
                }
            }
        }
    }

    private func startUpdaterIfNeeded() {
        guard !started else { return }
        updaterController.startUpdater()
        started = true
        objectWillChange.send()
        if pendingManualCheck {
            pendingManualCheck = false
            updater.checkForUpdates()
        }
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        activeFeedURL?.absoluteString
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        isRelaunchingForUpdate = true
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        isRelaunchingForUpdate = false
    }
}
