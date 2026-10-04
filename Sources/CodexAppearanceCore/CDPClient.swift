import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

public struct CDPTarget: Codable, Equatable, Sendable {
    public let id: String
    public let type: String
    public let url: String
    public let webSocketDebuggerURL: String?

    public init(id: String, type: String, url: String, webSocketDebuggerURL: String?) {
        self.id = id
        self.type = type
        self.url = url
        self.webSocketDebuggerURL = webSocketDebuggerURL
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, url
        case webSocketDebuggerURL = "webSocketDebuggerUrl"
    }
}

public enum CDPClientError: Error, Equatable, LocalizedError, Sendable {
    case invalidEndpoint(String)
    case invalidTargetURL(String)
    case mainTargetUnavailable
    case unexpectedResponseID(expected: Int, received: Int?)
    case remoteError(String)
    case timedOut
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let url): return "CDP endpoint must be loopback-only: \(url)"
        case .invalidTargetURL(let url): return "CDP target must be loopback-only: \(url)"
        case .mainTargetUnavailable: return "Codex main renderer is unavailable."
        case .unexpectedResponseID: return "CDP response did not match the request."
        case .remoteError(let message): return "CDP returned an error: \(message)"
        case .timedOut: return "CDP request timed out."
        case .invalidResponse: return "CDP returned an invalid response."
        }
    }
}

public protocol CDPConnecting: Sendable {
    func mainTarget() async throws -> CDPTarget
    func evaluate(_ expression: String, on target: CDPTarget) async throws -> JSONValue
}

public enum CDPWireResponse {
    private struct Envelope: Decodable {
        let id: Int?
        let result: JSONValue?
        let error: RemoteError?
    }

    private struct RemoteError: Decodable {
        let message: String?
    }

    public static func decode(data: Data, expectingID: Int) throws -> JSONValue {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.id == expectingID else {
            throw CDPClientError.unexpectedResponseID(expected: expectingID, received: envelope.id)
        }
        if let error = envelope.error {
            throw CDPClientError.remoteError(error.message ?? "Unknown remote error")
        }
        return envelope.result ?? .null
    }
}

public enum CDPWireRequest {
    public static func runtimeEvaluate(id: Int, expression: String) throws -> String {
        let body: JSONValue = .object([
            "id": .number(Double(id)),
            "method": .string("Runtime.evaluate"),
            "params": .object([
                "expression": .string(expression),
                "returnByValue": .bool(true),
                "awaitPromise": .bool(true)
            ])
        ])
        let data = try JSONEncoder().encode(body)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CDPClientError.invalidResponse
        }
        return text
    }
}

public actor CDPClient: CDPConnecting {
    public static let defaultEndpoint = URL(string: "http://127.0.0.1:39222/json/list")!

    private let endpoint: URL
    private let session: URLSession
    private let timeoutNanoseconds: UInt64
    private var requestID = 0

    public init(endpoint: URL = CDPClient.defaultEndpoint, session: URLSession = .shared, timeoutNanoseconds: UInt64 = 5_000_000_000) {
        self.endpoint = endpoint
        self.session = session
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    public static func validatedLoopbackURL(_ url: URL) throws -> URL {
        guard let scheme = url.scheme?.lowercased(), ["http", "https", "ws", "wss"].contains(scheme), isLoopbackHost(url.host) else {
            throw CDPClientError.invalidEndpoint(url.absoluteString)
        }
        return url
    }

    public static func selectMainTarget(from targets: [CDPTarget]) throws -> CDPTarget {
        guard let target = targets.first(where: isMainRenderer) else {
            throw CDPClientError.mainTargetUnavailable
        }
        guard let webSocketDebuggerURL = target.webSocketDebuggerURL, let url = URL(string: webSocketDebuggerURL), isLoopbackHost(url.host), ["ws", "wss"].contains(url.scheme?.lowercased() ?? "") else {
            throw CDPClientError.invalidTargetURL(target.webSocketDebuggerURL ?? "")
        }
        return target
    }

    public func mainTarget() async throws -> CDPTarget {
        let endpoint = try Self.validatedLoopbackURL(endpoint)
        let session = self.session
        let (data, response) = try await Self.withTimeout(nanoseconds: timeoutNanoseconds) {
            try await session.data(from: endpoint)
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw CDPClientError.mainTargetUnavailable
        }
        return try Self.selectMainTarget(from: JSONDecoder().decode([CDPTarget].self, from: data))
    }

    public func evaluate(_ expression: String, on target: CDPTarget) async throws -> JSONValue {
        guard let rawURL = target.webSocketDebuggerURL, let webSocketURL = URL(string: rawURL), Self.isLoopbackHost(webSocketURL.host), ["ws", "wss"].contains(webSocketURL.scheme?.lowercased() ?? "") else {
            throw CDPClientError.invalidTargetURL(target.webSocketDebuggerURL ?? "")
        }
        requestID += 1
        let currentRequestID = requestID
        let payload = try CDPWireRequest.runtimeEvaluate(id: currentRequestID, expression: expression)
        let task = session.webSocketTask(with: webSocketURL)
        task.resume()
        defer { task.cancel(with: .normalClosure, reason: nil) }
        try await Self.withTimeout(nanoseconds: timeoutNanoseconds) { try await task.send(.string(payload)) }
        let message = try await Self.withTimeout(nanoseconds: timeoutNanoseconds) { try await task.receive() }
        let responseData: Data
        switch message {
        case .data(let value): responseData = value
        case .string(let value): responseData = Data(value.utf8)
        @unknown default: throw CDPClientError.invalidResponse
        }
        return try CDPWireResponse.decode(data: responseData, expectingID: currentRequestID)
    }

    public static func withTimeout<T: Sendable>(nanoseconds: UInt64, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: nanoseconds)
                throw CDPClientError.timedOut
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private static func isMainRenderer(_ target: CDPTarget) -> Bool {
        guard target.type == "page", let url = URL(string: target.url) else { return false }
        return url.scheme == "app" && url.host == "-" && url.path == "/index.html" && !(url.fragment?.localizedCaseInsensitiveContains("overlay") ?? false) && !(url.query?.localizedCaseInsensitiveContains("overlay") ?? false)
    }

    private static func isLoopbackHost(_ host: String?) -> Bool {
        guard let host else { return false }
        return ["127.0.0.1", "localhost", "::1", "[::1]"].contains(host.lowercased())
    }
}
