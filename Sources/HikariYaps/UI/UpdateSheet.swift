import SwiftUI

struct UpdateSheet: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var isRebuilding = false
    @State private var buildOutput = ""
    @State private var buildSuccess = false
    @State private var showRelaunch = false

    private let projectPath = "/Users/daiskebrandan/Projects/iSuite/hikari-yaps"
    private let appVersion = "1.0.0"

    var body: some View {
        VStack(spacing: 20) {
            Text("iVoz")
                .font(.system(size: 20, weight: .bold))
            Text(L("update.version", appVersion))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            if isRebuilding {
                ProgressView()
                Text(L("update.rebuilding"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                if !buildOutput.isEmpty {
                    ScrollView {
                        Text(buildOutput)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 120)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                }
            } else if showRelaunch {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.success)
                Text(L("update.success"))
                    .font(.system(size: 15, weight: .semibold))
                Button(L("update.relaunch_button")) {
                    relaunchApp()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text(L("update.description"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)

                Button(L("update.rebuild_button")) {
                    rebuild()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRebuilding)
            }

            Button(L("common.close")) {
                dismiss()
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.escape)
        }
        .padding(24)
        .frame(width: 380)
    }

    private func rebuild() {
        isRebuilding = true
        buildOutput = ""

        Task {
            let result = await runMakeInstall()
            await MainActor.run {
                isRebuilding = false
                buildOutput = result.output
                buildSuccess = result.success
                showRelaunch = result.success
            }
        }
    }

    private func runMakeInstall() async -> (success: Bool, output: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/make")
        task.arguments = ["install"]
        task.currentDirectoryURL = URL(fileURLWithPath: projectPath)

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (task.terminationStatus == 0, output)
        } catch {
            return (false, "Error: \(error.localizedDescription)")
        }
    }

    private func relaunchApp() {
        let appPath = "/Applications/Hikari Yaps.app"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", appPath]
        try? task.run()
        NSApp.terminate(nil)
    }
}
