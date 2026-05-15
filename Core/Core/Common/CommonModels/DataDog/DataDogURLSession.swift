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

import DatadogTrace
import Foundation

/// URLSession delegate used for Datadog URLSession instrumentation.
/// Conforms to URLSessionDataDelegate (which covers URLSessionTaskDelegate)
/// and preserves the existing Authorization header on redirects.
public final class DataDogSessionDelegate: NSObject, URLSessionDataDelegate {
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        var newRequest = request
        if let authorizationHeader = task.originalRequest?.value(forHTTPHeaderField: HttpHeader.authorization),
           request.url?.host == AppEnvironment.shared.currentSession?.baseURL.host {
            newRequest.addValue(authorizationHeader, forHTTPHeaderField: HttpHeader.authorization)
        }
        completionHandler(newRequest)
    }
}

public extension URLSession {
    /// A shared `URLSession` instrumented for Datadog APM tracing.
    /// Use this session (or register `DataDogSessionDelegate` via
    /// `URLSessionInstrumentation.enable`) to have all network requests
    /// appear as traces in Datadog APM.
    static let instrumented: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        return URLSession(
            configuration: configuration,
            delegate: DataDogSessionDelegate(),
            delegateQueue: nil
        )
    }()
}
