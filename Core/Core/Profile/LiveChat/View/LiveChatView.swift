//
// This file is part of Canvas.
// Copyright (C) 2024-present  Instructure, Inc.
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

import SwiftUI

struct LiveChatView: View, ScreenViewTrackable {
    public let screenViewTrackingParameters = ScreenViewTrackingParameters(eventName: "/profile/chat")

    @Environment(\.appEnvironment) var env
    @Environment(\.viewController) var controller

    @StateObject var model: LiveChatViewModel = .init()

    var body: some View {
        ZStack {
            if model.currentChatType == .xpert {
                WebView(html: model.xpertHTML, wkEvents: model.wkEvents)
                    .opacity(model.hideWebviewWhileLoading ? 0 : 1)
            } else {
                WebView(html: model.five9HTML, wkEvents: model.wkEvents)
                    .opacity(model.hideWebviewWhileLoading ? 0 : 1)
            }
            if model.hideWebviewWhileLoading {
                LoadingView()
            }
        }
        .onChange(of: model.isDisplaying) { value in
            if !value {
                env.router.dismiss(controller)
            }
        }
    }
}

#Preview {
    LiveChatView()
}
