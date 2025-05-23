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

public struct CourseSmartSearchFilterEditorView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.courseSmartSearchContext) private var searchContext

    @StateObject var viewModel: CourseSearchFilterEditorViewModel

    public init(model: CourseSearchFilterEditorViewModel) {
        self._viewModel = StateObject(wrappedValue: model)
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 0) {

                    InstUI.Divider()

                    MultiSelectionView(
                        title: String(localized: "Result types", bundle: .core),
                        hasAllSelectionButton: true,
                        options: viewModel.resultTypeOptions
                    )

                    SingleSelectionView(
                        title: String(localized: "Grouped By", bundle: .core),
                        options: viewModel.sortModeOptions
                    )
                }
            }
            .listStyle(.plain)
            .navigationBarTitleView(String(localized: "Search Preferences", bundle: .core))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.cancel()
                        dismiss()
                    } label: {
                        Text("Cancel", bundle: .core)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done", bundle: .core)
                    }
                }
            }
            // Not using `.navigationBarStyle(.modal)` here, because that sets the navigatonBar's background color of its `CoreHostingViewController`,
            // and this screen (the only one in the whole project) is being presented via the `.sheet()` modifier instead of `router(show:)`
            // AND expected to have a Navigation Bar as well. That would turn the presenting screen's NavigationBar background color to white as well.
            .environment(\.navBarColors, .init(style: .modal))
        }
        .tint(contextColor)
    }

    private var contextColor: Color {
        return searchContext.accentColor?.asColor ?? .textDarkest
    }
}

// MARK: - Helpers

private extension EdgeInsets {
    static var filterRow: EdgeInsets {
        return EdgeInsets(top: 2, leading: 0, bottom: 0, trailing: 12)
    }
}
