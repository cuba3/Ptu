// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import SwiftUI

struct SettingsView: View {
    @State private var model = SettingsViewModel()

    var body: some View {
        Form {
            Picker(L10n.Settings.language, selection: $model.language) {
                ForEach(AppLanguage.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            Text(L10n.Settings.restart)
                .font(.callout)
                .foregroundStyle(Theme.secondaryLabel)
        }
        .padding(Theme.spacing)
        .frame(width: 420)
        .onChange(of: model.language) { _, _ in
            model.saveLanguage()
        }
    }
}
