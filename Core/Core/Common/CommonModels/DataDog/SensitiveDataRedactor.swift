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

/// Utility for redacting sensitive information from URLs and messages
/// to prevent exposure of tokens, credentials, and PII in Datadog logs.
public enum SensitiveDataRedactor {

    /// Patterns of sensitive data to redact
    private static let sensitivePatterns = [
        // Authentication
        "token=([^&]*)",
        "wstoken=([^&]*)",
        "access_token=([^&]*)",
        "authorization\\s*=\\s*([^&]*)",
        "bearer\\s+([^&\\s]*)",
        
        // Credentials
        "password=([^&]*)",
        "passwd=([^&]*)",
        "pwd=([^&]*)",
        
        // Personal info
        "email=([^&]*)",
        "api_key=([^&]*)",
        "apikey=([^&]*)",
        "secret=([^&]*)",
        "session=([^&]*)",
        "sessionid=([^&]*)"
    ]

    /// Redacts sensitive information from a URL string or message.
    ///
    /// Replaces sensitive values (tokens, passwords, emails, IDs) with `***`
    /// while preserving the parameter names for debugging purposes.
    ///
    /// Example:
    /// - Input:  `"GET /api/v1/courses?token=abc123&email=user@example.com"`
    /// - Output: `"GET /api/v1/courses?token=***&email=***"`
    ///
    /// - Parameter input: The string to redact (URL, error message, etc.)
    /// - Returns: The redacted string with sensitive values masked.
    static public func redact(_ input: String) -> String {
        var result = input
        for pattern in sensitivePatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: "$0=***"
                )
            } catch {
                // If regex fails, skip this pattern and continue
                continue
            }
        }
        return result
    }
}
