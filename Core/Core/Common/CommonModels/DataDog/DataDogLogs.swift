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

import Foundation
import DatadogCore
import DatadogLogs

public class DataDogLogs {
    public static let shared = DataDogLogs()

    private var _logger: DatadogLogs.LoggerProtocol?

    private var logger: DatadogLogs.LoggerProtocol? {
        if let _logger { return _logger }
        guard Datadog.isInitialized() else { return nil }
        _logger = DatadogLogs.Logger.create(
            with: DatadogLogs.Logger.Configuration(
                name: "IOS",
                networkInfoEnabled: true,
                remoteLogThreshold: .info,
                consoleLogFormat: .shortWith(prefix: "[iOS App] ")
            )
        )
        return _logger
    }

    public func log(info: String, context: [String: Encodable]? = nil) {
        guard let logger else {
            print("⚠️ DatadogLogs logger not available. Message: \(info)")
            return
        }

        var attributes = context ?? [:]
        attributes["context"] = "onboarding flow"

        logger.info(info, attributes: attributes)
    }
}
