import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct RecipeClipBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupRestoreView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var exportDocument = RecipeClipBackupDocument()
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingBackup: RecipeClipBackup?
    @State private var message: BackupMessage?

    var body: some View {
        List {
            Section {
                Button {
                    prepareExport()
                } label: {
                    Label("バックアップを書き出す", systemImage: "square.and.arrow.up")
                }

                Button {
                    isImporting = true
                } label: {
                    Label("バックアップから復元", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("データを守る")
            } footer: {
                Text("料理名、動画リンク、サムネイル、材料、手順、メモ、お気に入り、買い物リストを1つのファイルに保存するよ。")
            }

            Section("おすすめの使い方") {
                Label("機種変更やアプリ削除の前に書き出す", systemImage: "iphone.gen3")
                Label("ファイルはiCloud Driveなど安全な場所に保管する", systemImage: "lock.doc")
            }

            Section {
                Label("復元すると、現在のレシピと買い物リストはバックアップの内容に置き換わるよ。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
        .navigationTitle("バックアップと復元")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: defaultFilename
        ) { result in
            switch result {
            case .success:
                message = .init(title: String(localized: "バックアップ完了"), text: String(localized: "ファイルを書き出したよ。大切に保管してね。"))
            case .failure(let error):
                message = .init(title: String(localized: "書き出せなかったよ"), text: error.localizedDescription)
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let didAccess = url.startAccessingSecurityScopedResource()
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                pendingBackup = try BackupService.decode(Data(contentsOf: url))
            } catch {
                message = .init(title: String(localized: "読み込めなかったよ"), text: error.localizedDescription)
            }
        }
        .confirmationDialog(
            "バックアップから復元する？",
            isPresented: Binding(
                get: { pendingBackup != nil },
                set: { if !$0 { pendingBackup = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("現在のデータを置き換えて復元", role: .destructive) {
                restorePendingBackup()
            }
            Button("キャンセル", role: .cancel) { pendingBackup = nil }
        } message: {
            Text(String.localizedStringWithFormat(String(localized: "backup.summary"), pendingBackup?.recipes.count ?? 0, pendingBackup?.shoppingItems.count ?? 0))
        }
        .alert(item: $message) { message in
            Alert(title: Text(message.title), message: Text(message.text), dismissButton: .default(Text("OK")))
        }
    }

    private var defaultFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "動画レシピ帳_\(formatter.string(from: .now))"
    }

    private func prepareExport() {
        do {
            exportDocument = RecipeClipBackupDocument(
                data: try BackupService.encode(BackupService.makeBackup(from: modelContext))
            )
            isExporting = true
        } catch {
            message = .init(title: String(localized: "バックアップを作れなかったよ"), text: error.localizedDescription)
        }
    }

    private func restorePendingBackup() {
        guard let backup = pendingBackup else { return }
        pendingBackup = nil
        do {
            try BackupService.restore(backup, into: modelContext)
            message = .init(title: String(localized: "復元完了"), text: String(localized: "レシピと買い物リストを復元したよ。"))
        } catch {
            modelContext.rollback()
            message = .init(title: String(localized: "復元できなかったよ"), text: error.localizedDescription)
        }
    }
}

private struct BackupMessage: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}
