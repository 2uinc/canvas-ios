//
// This file is part of Canvas.
// Copyright (C) 2026-present  Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

#if DEBUG
import Foundation
import os.log

// MARK: - OSLog category

private extension OSLog {
    static let api = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "com.instructure.canvas",
        category: "api"
    )
}

// MARK: - Logger

enum APIRequestLogger {

    /// Logs a completed API request to the Xcode console in a structured,
    /// human-readable format. Active only in DEBUG builds.
    ///
    /// - Parameters:
    ///   - request:   The outgoing `URLRequest`.
    ///   - response:  The raw `URLResponse` received, if any.
    ///   - data:      The response body `Data`, if any.
    ///   - error:     Any transport-level `Error` that occurred.
    ///   - startedAt: The timestamp captured just before the request was fired.
    static func log(
        request: URLRequest,
        response: URLResponse?,
        data: Data?,
        error: Error?,
        startedAt: Date
    ) {
        let duration   = Date().timeIntervalSince(startedAt)
        let method     = request.httpMethod ?? "UNKNOWN"
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        let isFailure  = error != nil || statusCode >= 400

        // ── 1. Status line ────────────────────────────────────────────────
        let host       = request.url?.host ?? ""
        let path       = request.url?.path ?? "n/a"
        let rawQuery   = request.url?.query ?? ""
        let urlDisplay = removeSensitive(from: "\(host)\(path)\(rawQuery.isEmpty ? "" : "?\(rawQuery)")")
        let typeLabel  = isFailure ? "[ERROR] " : ""
        let statusLine = "\(typeLabel)[\(statusCode)] \(method) \(urlDisplay)"
            + String(format: ", took %.2fs", duration)

        // ── 2. Request headers ────────────────────────────────────────────
        var headersSection: String?
        if let fields = request.allHTTPHeaderFields, !fields.isEmpty {
            let lines = fields
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \(redactSensitiveHeader(key: $0.key, value: $0.value))" }
                .joined(separator: "\n     ")
            headersSection = "Request Headers:\n     \(lines)"
        }

        // ── 3. Request body ───────────────────────────────────────────────
        var bodySection: String?
        if let body = request.httpBody,
           let raw  = String(data: body, encoding: .utf8),
           !raw.isEmpty {
            bodySection = "Request Body: " + removeSensitive(from: raw).truncated(2048)
        }

        // ── 4. App state ──────────────────────────────────────────────────
        let version    = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build      = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let threadName = Thread.current.isMainThread ? "main" : "background"
        let appState   = "Version: \(version), Build: \(build), Thread: \(threadName)"

        // ── 5. Response body ──────────────────────────────────────────────
        var responseSection: String?
        if let data = data, let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
            let truncated = raw.prefix(512) + (raw.count > 512 ? "..." : "")
            responseSection = "Response: \(truncated)"
        }

        // ── 6. Error ──────────────────────────────────────────────────────
        var errorSection: String?
        if let error = error {
            errorSection = "Error: \(error)"
        }

        // ── Compose ───────────────────────────────────────────────────────
        let message = [
            "",
            statusLine,
            headersSection,
            bodySection,
            appState,
            responseSection,
            errorSection
        ]
        .compactMap { $0 }
        .joined(separator: "\n ▧ ")

        os_log(
            "%{public}@",
            log: .api,
            type: isFailure ? .error : .default,
            message
        )
    }

    // MARK: - Helpers

    /// Redacts sensitive query-string / body values after a matching key.
    private static func removeSensitive(from string: String) -> String {
        let sensitiveKeys = ["password", "token", "wstoken", "privatetoken"]
        var result = string
        for key in sensitiveKeys {
            if let range = result.range(of: key, options: .caseInsensitive) {
                result = String(result.prefix(upTo: range.lowerBound)) + "...[hidden]"
            }
        }
        return result
    }

    /// Redacts entire header values whose key is security-sensitive.
    private static func redactSensitiveHeader(key: String, value: String) -> String {
        let sensitiveKeys = ["authorization", "token", "cookie", "x-api-key"]
        if sensitiveKeys.contains(where: { key.lowercased().contains($0) }) {
            return "...[hidden]"
        }
        return value
    }
}

// MARK: - String helpers

private extension String {
    func truncated(_ maxLength: Int = 1024) -> String {
        guard count > maxLength else { return self }
        return "\(prefix(maxLength))..."
    }
}
#endif
