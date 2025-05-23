//
// This file is part of Canvas.
// Copyright (C) 2021-present  Instructure, Inc.
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

struct SideMenuMainSection: View {
    @Environment(\.appEnvironment) private var env
    @Environment(\.viewController) private var controller

    @ObservedObject private var tools: Store<GetGlobalNavExternalToolsPlacements>
    @State private var unreadCount: UInt = 0
    @State private var canUpdateAvatar: Bool = false

    private let enrollment: HelpLinkEnrollment
    private var dashboard: UIViewController {
        guard var dashboard = controller.value.presentingViewController else {
            return UIViewController()
        }
        if let tabs = dashboard as? UITabBarController {
            dashboard = tabs.selectedViewController ?? tabs
        }
        if let split = dashboard as? UISplitViewController {
            dashboard = split.masterNavigationController ?? split
        }

        return dashboard
    }
    @ObservedObject private var offlineModeViewModel: OfflineModeViewModel

    init(_ enrollment: HelpLinkEnrollment, offlineModeViewModel: OfflineModeViewModel = OfflineModeViewModel(interactor: OfflineModeAssembly.make())) {
        self.enrollment = enrollment
        let env = AppEnvironment.shared
        self.tools = env.subscribe(GetGlobalNavExternalToolsPlacements(enrollment: enrollment))
        self.offlineModeViewModel = offlineModeViewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            if enrollment == .observer {
                PrimaryButton(isAvailable: !$offlineModeViewModel.isOffline) {
                    route(to: "/conversations")
                } label: {
                    SideMenuItem(id: "inbox", image: .emailLine, title: Text("Inbox", bundle: .core), badgeValue: $unreadCount).onAppear {
                        env.api.makeRequest(GetConversationsUnreadCountRequest()) { (response, _, _) in
                            self.unreadCount = response?.unread_count ?? 0
                        }
                    }
                }
                .buttonStyle(ContextButton(contextColor: Brand.shared.primary))

                PrimaryButton(isAvailable: !$offlineModeViewModel.isOffline) {
                    route(to: "/profile/observees")
                } label: {
                    SideMenuItem(id: "manageChildren", image: .groupLine, title: Text("Manage Students", bundle: .core))
                }
                .buttonStyle(ContextButton(contextColor: Brand.shared.primary))
            } else {
                PrimaryButton(isAvailable: !$offlineModeViewModel.isOffline) {
                    route(to: "/users/self/files")
                } label: {
                    SideMenuItem(id: "files", image: .folderLine, title: Text("Files", bundle: .core))
                }
                .buttonStyle(ContextButton(contextColor: Brand.shared.primary))
            }

            ForEach(Array(tools), id: \.self) { tool in
                PrimaryButton(isAvailable: !$offlineModeViewModel.isOffline) {
                    launchLTI(url: tool.url)
                } label: {
                    SideMenuItem(id: "lti.\(tool.domain ?? "").\(tool.definitionID)",
                                 image: imageForDomain(tool.domain),
                                 title: Text("\(tool.title)", bundle: .core))
                }
                .buttonStyle(ContextButton(contextColor: Brand.shared.primary))
            }

            Button {
                route(to: "/profile/settings", options: .modal(.formSheet, embedInNav: true, addDoneButton: true))
            } label: {
                    SideMenuItem(
                        id: "settings",
                        image: .settingsLine,
                        title: Text("Settings", bundle: .core)
                    )
            }
            .buttonStyle(ContextButton(contextColor: Brand.shared.primary))
        }
        .onAppear {
            tools.refresh()
        }
    }

    func imageForDomain(_ domain: String?) -> Image {
        guard let ltiDomain = LTIDomains(rawValue: domain ?? "") else {
            return LTIDomains.defaultIcon
        }

        return ltiDomain.icon
    }

    func route(to: String, options: RouteOptions = .push) {
        let dashboard = self.dashboard
        env.router.dismiss(controller) {
            self.env.router.route(to: to, from: dashboard, options: options)
        }
    }

    func launchLTI(url: URL?) {
        guard let url = url else { return }
        let dashboard = self.dashboard
        env.router.dismiss(controller) { [env] in
            LTITools(url: url, isQuizLTI: false, env: env)
                .presentTool(from: dashboard, animated: true)
        }
    }
}

#if DEBUG

struct SideMenuMainSection_Previews: PreviewProvider {
    static var previews: some View {
        SideMenuMainSection(.student)
    }
}

#endif
