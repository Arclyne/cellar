import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BottleDetailView: View {
    private enum FileSelectionPurpose {
        case installer
        case program

        var allowedContentTypes: [UTType] {
            switch self {
            case .installer: WindowsFileTypes.installers
            case .program: WindowsFileTypes.executables
            }
        }
    }

    let bottle: Bottle

    @Environment(BottleLibrary.self) private var library
    @State private var isSelectingFile = false
    @State private var fileSelectionPurpose = FileSelectionPurpose.installer
    @State private var programPendingShortcut: BottleProgram?
    @State private var isPresentingRecipeComponentsSheet = false

    private let programGridColumns = [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BottleHeader(bottle: bottle)
                if bottle.programs.isEmpty {
                    emptyProgramsPlaceholder
                } else {
                    programGrid
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(bottle.name)
        .toolbar {
            ToolbarItem {
                bottleActionsMenu
            }
        }
        .fileImporter(
            isPresented: $isSelectingFile,
            allowedContentTypes: fileSelectionPurpose.allowedContentTypes
        ) { selection in
            handleFileSelection(selection)
        }
        .sheet(item: $programPendingShortcut) { program in
            AppShortcutSheet(program: program, bottle: bottle)
                .environment(library)
        }
        .sheet(isPresented: $isPresentingRecipeComponentsSheet) {
            RecipeComponentsSheet(bottle: bottle)
                .environment(library)
        }
        .fileDialogDefaultDirectory(fileSelectionPurpose == .program ? library.driveCDirectory(of: bottle) : nil)
    }

    private var programGrid: some View {
        LazyVGrid(columns: programGridColumns, alignment: .leading, spacing: 16) {
            ForEach(bottle.programs) { program in
                ProgramTile(program: program, bottle: bottle)
                    .onTapGesture(count: 2) {
                        library.launch(program, in: bottle)
                    }
                    .contextMenu {
                        Button("Open") {
                            library.launch(program, in: bottle)
                        }
                        Button("Create App Shortcut…") {
                            programPendingShortcut = program
                        }
                        Divider()
                        Button("Remove from Bottle", role: .destructive) {
                            library.removeProgram(program, from: bottle)
                        }
                    }
            }
        }
    }

    private var emptyProgramsPlaceholder: some View {
        ContentUnavailableView {
            Label("No Programs", systemImage: "app.dashed")
        } description: {
            Text("Run an installer, or add a program that is already inside this bottle.")
        } actions: {
            Button("Run Installer…") {
                selectFile(for: .installer)
            }
            .disabled(library.isBusy)
            Button("Add Program…") {
                selectFile(for: .program)
            }
        }
    }

    private var bottleActionsMenu: some View {
        Menu {
            Button("Run Installer…") {
                selectFile(for: .installer)
            }
            .disabled(library.isBusy)
            Button("Add Program…") {
                selectFile(for: .program)
            }
            Button("Install Recipe Components…") {
                isPresentingRecipeComponentsSheet = true
            }
            .disabled(library.isBusy)
            Divider()
            Button("Open C: Drive") {
                library.openDriveC(of: bottle)
            }
            Button("Show Log in Finder") {
                library.revealLog(of: bottle)
            }
            Divider()
            Button("Stop All Programs") {
                Task { await library.stopAllPrograms(in: bottle) }
            }
            .disabled(library.isBusy)
        } label: {
            Label("Bottle Actions", systemImage: "ellipsis.circle")
        }
        .help("Bottle actions")
    }

    private func selectFile(for purpose: FileSelectionPurpose) {
        fileSelectionPurpose = purpose
        isSelectingFile = true
    }

    private func handleFileSelection(_ selection: Result<URL, Error>) {
        guard case .success(let selectedURL) = selection else { return }
        switch fileSelectionPurpose {
        case .installer:
            Task { await library.runInstaller(at: selectedURL, in: bottle) }
        case .program:
            library.addProgram(at: selectedURL, to: bottle)
        }
    }
}

struct BottleHeader: View {
    let bottle: Bottle

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "wineglass.fill")
                .font(.system(size: 28))
                .foregroundStyle(.tint)
                .frame(width: 56, height: 56)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(bottle.name)
                    .font(.title2.weight(.semibold))
                Text("\(bottle.windowsVersion.displayName) · \(programCountDescription)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var programCountDescription: String {
        bottle.programs.count == 1 ? "1 program" : "\(bottle.programs.count) programs"
    }
}

struct ProgramTile: View {
    let program: BottleProgram
    let bottle: Bottle

    @Environment(BottleLibrary.self) private var library
    @State private var programIcon: NSImage?

    var body: some View {
        let programActivity = library.activity(of: program)
        VStack(spacing: 6) {
            iconView
                .frame(width: 64, height: 64)
                .opacity(programActivity == .opening ? 0.45 : 1)
                .overlay {
                    if programActivity == .opening {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if programActivity == .running {
                        Circle()
                            .fill(.green)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 2))
                            .offset(x: 3, y: 3)
                    }
                }
            Text(program.displayName)
                .font(.callout)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(statusDescription(for: programActivity))
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(programActivity == nil ? 0 : 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .help(program.windowsPath)
        .task(id: program.windowsPath) {
            guard let iconData = await library.iconData(for: program, in: bottle) else { return }
            programIcon = NSImage(data: iconData)
        }
    }

    private func statusDescription(for programActivity: ProgramActivity?) -> String {
        switch programActivity {
        case .opening?: "Opening…"
        case .running?: "Running"
        case nil: " "
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let programIcon {
            Image(nsImage: programIcon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "macwindow")
                .font(.system(size: 30))
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
