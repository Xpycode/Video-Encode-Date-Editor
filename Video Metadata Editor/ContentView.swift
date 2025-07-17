import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct EncodeDate: View {
    @StateObject private var viewModel = EncodeDate()
    @Environment(\.colorScheme) var systemColorScheme
    @State private var showingAbout = false
    
    // Get version from Bundle - single source of truth from Xcode build settings
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        _ = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "v\(version)"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Simple header with just the subtitle
            HStack {
                Text("Change encoded date to match creation date")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                
                // About button
                Button(action: {
                    showingAbout = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("About Video Metadata Editor")
            }
            .padding(.top, 8)

            
            // File selection area - takes up most space
            if viewModel.selectedFiles.isEmpty {
                EmptySelectionView(viewModel: viewModel)
            } else {
                FileListView(viewModel: viewModel)
            }
            
            // Processing progress (only when processing)
            if viewModel.isProcessing {
                ProcessingProgressView(viewModel: viewModel)
            }
            
            Spacer() // Push everything below to bottom
            
            // Output filename customization
            VStack(spacing: 10) {
                HStack {
                    Toggle("Append suffix to output files", isOn: $viewModel.appendSuffix)
                    
                    if viewModel.appendSuffix {
                        Text("Suffix:")
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)
                        TextField("_processed", text: $viewModel.outputSuffix)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 150)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Toggle("Overwrite existing files without asking", isOn: $viewModel.overwriteAll)
                    Spacer()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            
            // Buttons and status - above summary
            VStack(spacing: 15) {
                // Buttons
                HStack(spacing: 25) {
                    Button("Select Destination Folder") {
                        viewModel.selectOutputFolder()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(viewModel.selectedFiles.count == 1 ? "Process Video" : "Process Videos") {
                        viewModel.processAllVideos()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.selectedFiles.isEmpty || viewModel.isProcessing || viewModel.filesNeedingUpdate == 0 || viewModel.outputDirectory == nil)
                }
                
                // Output folder display - below buttons
                if let outputDir = viewModel.outputDirectory {
                    HStack {
                        Text("Destination Folder:")
                            .foregroundColor(.secondary)
                        Text(outputDir.lastPathComponent)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .font(.caption)
                }
                
                // Status message
                if !viewModel.statusMessage.isEmpty && !viewModel.isProcessing {
                    Text(viewModel.statusMessage)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(viewModel.hasError ? .red : .green)
                }
            }
            
            // Bottom section - summary
            if !viewModel.selectedFiles.isEmpty {
                BatchSummaryView(viewModel: viewModel)
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 500)
        .navigationTitle(windowTitle)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .sheet(isPresented: $showingAbout) {
            AboutView(version: appVersion)
        }
    }
    
    private var windowTitle: String {
        if viewModel.selectedFiles.isEmpty {
            return "Video Metadata Editor \(appVersion)"
        } else {
            return "Video Metadata Editor \(appVersion) - \(viewModel.selectedFiles.count) file\(viewModel.selectedFiles.count == 1 ? "" : "s")"
        }
    }
}

func getFFToolVersion(tool: String) -> String {
    guard let toolPath = Bundle.main.path(forResource: tool, ofType: nil) else {
        return "\(tool) not found in bundle"
    }
    
    let process = Process()
    let pipe = Pipe()
    
    process.executableURL = URL(fileURLWithPath: toolPath)
    process.arguments = ["-version"]
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            return output.components(separatedBy: .newlines).first ?? "\(tool) version unknown"
        }
    } catch {
        return "Error running \(tool): \(error.localizedDescription)"
    }
    
    return "Unknown error getting version"
}



struct AboutView: View {
    let version: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var ffmpegVersion: String = "Loading..."
    @State private var ffprobeVersion: String = "Loading..."
    
    var body: some View {
        VStack(spacing: 20) {
            // App icon placeholder
            Image("AppIcon256")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
            
            VStack(spacing: 8) {
                Text("Video Metadata Editor")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version \(version)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Change Encoded Date to File Creation Date")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider()
            
            VStack(spacing: 12) {
                Text("Features:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Batch video metadata processing")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Drag & drop file selection")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Custom output filename suffixes")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Automatic dark mode support")
                    }
                }
                .font(.caption)
            }
            
            Divider()
            
            VStack(spacing: 4) {
                Text("FFmpeg & FFprobe are bundled within the app:")
                
                Text("FFmpeg: \(ffmpegVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("FFprobe: \(ffprobeVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
            
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(30)
        .frame(width: 400, height: 520)
        .onAppear {
            ffmpegVersion = getFFToolVersion(tool: "ffmpeg")
            ffprobeVersion = getFFToolVersion(tool: "ffprobe")
        }
    }
}


enum ColorSchemePreference: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case auto = "Auto"
}

struct EmptySelectionView: View {
    @ObservedObject var viewModel: VideoMetadataViewModel
    
    var body: some View {
        Button(action: {
            viewModel.selectFiles()
        }) {
            VStack(spacing: 10) {
                Image(systemName: "plus.circle.dashed")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                Text("Select Video Files")
                    .font(.headline)
                Text("Choose files or drag & drop video files here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            viewModel.handleDrop(providers: providers)
        }
    }
}

struct FileListView: View {
    @ObservedObject var viewModel: VideoMetadataViewModel
    @Environment(\.colorScheme) var systemColorScheme
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(viewModel.selectedFiles.count) file\(viewModel.selectedFiles.count == 1 ? "" : "s") selected")
                    .font(.headline)
                Spacer()
                Button("Add More Files") {
                    viewModel.selectFiles()
                }
                .buttonStyle(.bordered)
                Button("Clear All") {
                    viewModel.clearSelection()
                }
                .buttonStyle(.bordered)
            }
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.selectedFiles.enumerated()), id: \.element) { index, file in
                        FileRowView(
                            file: file,
                            viewModel: viewModel,
                            index: index
                        )
                    }
                }
                .padding(.vertical, 5)
            }
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            viewModel.handleDrop(providers: providers)
        }
    }
}

struct FileRowView: View {
    let file: URL
    @ObservedObject var viewModel: VideoMetadataViewModel
    let index: Int
    @Environment(\.colorScheme) var systemColorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            VStack {
                if viewModel.isProcessing && viewModel.currentProcessingIndex == index {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: statusIcon)
                        .foregroundColor(statusColor)
                        .font(.title2)
                }
            }
            .frame(width: 30)
            
            // File information
            VStack(alignment: .leading, spacing: 4) {
                // Top row: Filename and dates
                HStack(alignment: .center, spacing: 8) {
                    // Left side: File name with size
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.lastPathComponent)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        if let fileSize = viewModel.getFileSize(for: file) {
                            Text(fileSize)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .layoutPriority(1) // Give filename priority
                    
                    Spacer(minLength: 8)
                    
                    // Right side: Date information (compact and aligned)
                    if let info = viewModel.fileInfos[file] {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("Creation:")
                                    .fontWeight(.medium)
                                    .font(.caption2)
                                    .frame(minWidth: 50, alignment: .trailing)
                                Text(info.creationDate)
                                    .font(.caption2)
                                    .foregroundColor(info.datesMatch ?
                                        (systemColorScheme == .dark ? Color.green : Color(red: 0.0, green: 0.6, blue: 0.0)) :
                                        (systemColorScheme == .dark ? Color.yellow : Color.orange))
                                    .fontWeight(.medium)
                                    .monospaced()
                            }
                            
                            HStack(spacing: 4) {
                                Text("Encoded:")
                                    .fontWeight(.medium)
                                    .font(.caption2)
                                    .frame(minWidth: 50, alignment: .trailing)
                                Text(info.encodedDate ?? "Not set")
                                    .font(.caption2)
                                    .foregroundColor(info.encodedDate != nil ?
                                        (info.datesMatch ?
                                            (systemColorScheme == .dark ? Color.green : Color(red: 0.0, green: 0.6, blue: 0.0)) :
                                            (systemColorScheme == .dark ? Color.yellow : Color.orange)) :
                                        .gray)
                                    .fontWeight(.medium)
                                    .monospaced()
                            }
                        }
                        .fixedSize() // Prevent text wrapping
                    }
                }
                
                // Individual progress bar when processing this file
                if viewModel.isProcessing && viewModel.currentProcessingIndex == index {
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 4)
                }
            }
            
            Spacer()
            
            // Remove button
            Button(action: {
                viewModel.removeFile(file)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Group {
                if viewModel.isProcessing && viewModel.currentProcessingIndex == index {
                    systemColorScheme == .dark ? Color.blue.opacity(0.25) : Color.blue.opacity(0.1)
                } else if index % 2 == 0 {
                    systemColorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.15)
                } else {
                    Color.clear
                }
            }
        )
        .cornerRadius(6)
    }
    
    private var statusIcon: String {
        guard let info = viewModel.fileInfos[file] else { return "questionmark.circle" }
        return info.datesMatch ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }
    
    private var statusColor: Color {
        guard let info = viewModel.fileInfos[file] else { return .gray }
        return info.datesMatch ?
            (systemColorScheme == .dark ? Color.green : Color(red: 0.0, green: 0.6, blue: 0.0)) :
            (systemColorScheme == .dark ? Color.yellow : Color.orange)
    }
}

struct BatchSummaryView: View {
    @ObservedObject var viewModel: VideoMetadataViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Batch Processing Summary")
                .font(.headline)
            
            HStack {
                Text("Files needing update:")
                    .fontWeight(.medium)
                Text("\(viewModel.filesNeedingUpdate)")
                    .foregroundColor(.orange)
                Spacer()
                Text("Files already up to date:")
                    .fontWeight(.medium)
                Text("\(viewModel.filesUpToDate)")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ProcessingProgressView: View {
    @ObservedObject var viewModel: VideoMetadataViewModel
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Processing file \(viewModel.currentProcessingIndex + 1) of \(viewModel.filesToProcess.count)")
                    .font(.headline)
                Spacer()
                Text("\(Int(viewModel.overallProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: viewModel.overallProgress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ActionButtonsView: View {
    @ObservedObject var viewModel: VideoMetadataViewModel
    
    var body: some View {
        HStack(spacing: 25) {
            Button("Process All Videos") {
                viewModel.processAllVideos()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedFiles.isEmpty || viewModel.isProcessing || viewModel.filesNeedingUpdate == 0)
            
            Button("Clear All") {
                viewModel.clearSelection()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.selectedFiles.isEmpty || viewModel.isProcessing)
        }
    }
}

struct VideoFileInfo {
    let creationDate: String
    let encodedDate: String?
    let needsUpdate: Bool
    
    // Add a computed property to determine if dates match for display
    var datesMatch: Bool {
        guard let encoded = encodedDate else { return false }
        // Simple string comparison for display purposes
        return creationDate == encoded
    }
}

@MainActor
class VideoMetadataViewModel: ObservableObject {
    @Published var selectedFiles: [URL] = []
    @Published var fileInfos: [URL: VideoFileInfo] = [:]
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var overallProgress: Double = 0.0
    @Published var statusMessage = ""
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var hasError = false
    @Published var currentProcessingIndex = 0
    @Published var outputDirectory: URL?
    @Published var isDragOver = false
    @Published var debugMessage = ""
    @Published var appendSuffix = true
    @Published var outputSuffix = "_processed"
    @Published var overwriteAll = false
    
    // Add file size caching
    private var fileSizeCache: [URL: String] = [:]
    
    var filesNeedingUpdate: Int {
        selectedFiles.compactMap { fileInfos[$0] }.filter { !$0.datesMatch }.count
    }
    
    var filesUpToDate: Int {
        selectedFiles.compactMap { fileInfos[$0] }.filter { $0.datesMatch }.count
    }
    
    var filesToProcess: [URL] {
        selectedFiles.filter { file in
            guard let info = fileInfos[file] else { return false }
            return !info.datesMatch
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd - HH:mm:ss"
        return formatter
    }()
    
    private let ffmpegDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    func selectFiles() {
        debugMessage = "🔍 Opening file selection dialog..."
        let panel = NSOpenPanel()
        panel.title = "Select Video Files"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.movie, UTType.quickTimeMovie, UTType.mpeg4Movie, UTType.avi]
        
        if panel.runModal() == .OK {
            let newFiles = panel.urls.filter { !selectedFiles.contains($0) }
            debugMessage = "📁 Selected \(newFiles.count) new files, loading info..."
            selectedFiles.append(contentsOf: newFiles)
            loadFileInfos()
        } else {
            debugMessage = "❌ File selection cancelled"
        }
    }
    
    func removeFile(_ file: URL) {
        selectedFiles.removeAll { $0 == file }
        fileInfos.removeValue(forKey: file)
        fileSizeCache.removeValue(forKey: file) // Remove from size cache too
        updateStatus()
    }
    
    func getFileSize(for url: URL) -> String? {
        // Check cache first
        if let cachedSize = fileSizeCache[url] {
            return cachedSize
        }
        
        // Calculate and cache file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                let sizeString = formatFileSize(fileSize)
                fileSizeCache[url] = sizeString
                return sizeString
            }
        } catch {
            // Silently fail for file size - not critical
        }
        return nil
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    func selectOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Output Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        
        if panel.runModal() == .OK {
            outputDirectory = panel.url
        }
    }
    
    func clearSelection() {
        selectedFiles.removeAll()
        fileInfos.removeAll()
        fileSizeCache.removeAll() // Clear size cache too
        statusMessage = ""
        hasError = false
        progress = 0.0
        overallProgress = 0.0
        outputDirectory = nil
        isDragOver = false
    }
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        Task { @MainActor in
                            await self.processDroppedURL(url)
                        }
                    } else if let url = item as? URL {
                        Task { @MainActor in
                            await self.processDroppedURL(url)
                        }
                    }
                }
            }
        }
        return true
    }
    
    private func processDroppedURL(_ url: URL) async {
        // Check if it's a video file by extension
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv", "webm"]
        let fileExtension = url.pathExtension.lowercased()
        
        if videoExtensions.contains(fileExtension) {
            if !self.selectedFiles.contains(url) {
                self.selectedFiles.append(url)
                await self.loadFileInfo(for: url)
                self.updateStatus()
            }
        }
    }
    
    private func loadFileInfos() {
        debugMessage = "⏳ Starting to load file information..."
        Task {
            for (index, file) in selectedFiles.enumerated() {
                if fileInfos[file] == nil {
                    debugMessage = "📖 Loading info for file \(index + 1)/\(selectedFiles.count): \(file.lastPathComponent)"
                    await loadFileInfo(for: file)
                }
            }
            debugMessage = "✅ Finished loading all file information"
            updateStatus()
        }
    }
    
    private func updateStatus() {
        if selectedFiles.isEmpty {
            statusMessage = ""
        } else if filesNeedingUpdate > 0 {
            statusMessage = "\(filesNeedingUpdate) file\(filesNeedingUpdate == 1 ? "" : "s") ready for processing"
            hasError = false
        } else {
            statusMessage = "All files are already up to date"
            hasError = false
        }
    }
    
    private func loadFileInfo(for file: URL) async {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            let creationDate = attributes[.creationDate] as? Date ?? Date()
            let creationDateString = dateFormatter.string(from: creationDate)
            
            let encodedDate = try await getCurrentEncodedDate(from: file)
            
            let needsUpdate: Bool
            if let encoded = encodedDate {
                let creationDateForComparison = dateFormatter.string(from: creationDate)
                needsUpdate = encoded != creationDateForComparison
            } else {
                needsUpdate = true
            }
            
            fileInfos[file] = VideoFileInfo(
                creationDate: creationDateString,
                encodedDate: encodedDate,
                needsUpdate: needsUpdate
            )
        } catch {
            showErrorAlert("Failed to load file info: \(error.localizedDescription)")
        }
    }
    
    private func getCurrentEncodedDate(from file: URL) async throws -> String? {
        let ffprobePath = try findExecutable("ffprobe")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffprobePath)
        process.arguments = ["-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", file.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Check format tags
            if let format = json["format"] as? [String: Any],
               let tags = format["tags"] as? [String: Any] {
                let keys = ["creation_time", "date", "encoded_date", "CREATION_TIME", "DATE", "com.apple.quicktime.creationdate", "creation_date"]
                for key in keys {
                    if let dateString = tags[key] as? String {
                        if let convertedDate = convertDateString(dateString) {
                            return convertedDate
                        }
                    }
                }
            }
            
            // Check stream tags
            if let streams = json["streams"] as? [[String: Any]] {
                for stream in streams {
                    if let tags = stream["tags"] as? [String: Any] {
                        let keys = ["creation_time", "date", "encoded_date", "CREATION_TIME", "DATE", "com.apple.quicktime.creationdate", "creation_date"]
                        for key in keys {
                            if let dateString = tags[key] as? String {
                                if let convertedDate = convertDateString(dateString) {
                                    return convertedDate
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func convertDateString(_ dateString: String) -> String? {
        // Try different input formats and convert to our standard display format
        let inputFormatters = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                return formatter
            }(),
            ISO8601DateFormatter()
        ]
        
        for formatter in inputFormatters {
            var date: Date?
            
            if let isoFormatter = formatter as? ISO8601DateFormatter {
                date = isoFormatter.date(from: dateString)
            } else if let dateFormatter = formatter as? DateFormatter {
                date = dateFormatter.date(from: dateString)
            }
            
            if let date = date {
                // Convert to our standard display format
                return dateFormatter.string(from: date)
            }
        }
        
        return nil
    }
    
    func processAllVideos() {
        Task {
            await processVideosSequentially()
        }
    }
    
    private func processVideosSequentially() async {
        isProcessing = true
        overallProgress = 0.0
        currentProcessingIndex = 0
        statusMessage = "Starting processing..."
        hasError = false
        
        let filesToProcess = self.filesToProcess
        
        guard !filesToProcess.isEmpty else {
            statusMessage = "No files need processing"
            isProcessing = false
            return
        }
        
        guard let outputDir = outputDirectory else {
            statusMessage = "Please select an output folder first"
            isProcessing = false
            return
        }
            
            for (index, file) in filesToProcess.enumerated() {
                currentProcessingIndex = selectedFiles.firstIndex(of: file) ?? index
                
                // Calculate overall progress
                overallProgress = Double(index) / Double(filesToProcess.count)
                
                // Generate output filename
                let outputFileName: String
                if self.appendSuffix && !self.outputSuffix.isEmpty {
                    outputFileName = file.deletingPathExtension().lastPathComponent + self.outputSuffix + "." + file.pathExtension
                } else {
                    outputFileName = file.lastPathComponent
                }
                let outputFile = outputDir.appendingPathComponent(outputFileName)
                
                // Check if file exists and warn user (unless overwrite all is enabled)
                if FileManager.default.fileExists(atPath: outputFile.path) && !self.overwriteAll {
                    let alert = NSAlert()
                    alert.messageText = "File Already Exists"
                    alert.informativeText = "The file '\(outputFileName)' already exists. Do you want to overwrite it?"
                    alert.addButton(withTitle: "Overwrite")
                    alert.addButton(withTitle: "Skip")
                    alert.addButton(withTitle: "Cancel All")
                    alert.alertStyle = .warning
                    
                    let response = alert.runModal()
                    if response == .alertSecondButtonReturn {
                        continue // Skip this file
                    } else if response == .alertThirdButtonReturn {
                        break // Cancel all processing
                    }
                    // If first button (Overwrite), continue with processing
                }
                
                await processVideoFile(input: file, output: outputFile, fileIndex: index + 1, totalFiles: filesToProcess.count)
                
                // Update overall progress
                overallProgress = Double(index + 1) / Double(filesToProcess.count)
                
                // Replace the original file with the processed file in our list
                if let fileIndex = selectedFiles.firstIndex(of: file) {
                    // Remove old file info first
                    fileInfos.removeValue(forKey: file)
                    
                    // Only replace if the output file is different from the input file
                    if outputFile != file {
                        // Check if output file already exists in our list
                        if let existingIndex = selectedFiles.firstIndex(of: outputFile) {
                            // Remove the existing entry to avoid duplicates
                            selectedFiles.remove(at: existingIndex)
                            fileInfos.removeValue(forKey: outputFile)
                            // Adjust fileIndex if needed
                            let adjustedIndex = existingIndex < fileIndex ? fileIndex - 1 : fileIndex
                            selectedFiles[adjustedIndex] = outputFile
                        } else {
                            selectedFiles[fileIndex] = outputFile
                        }
                    }
                }
                
                // Refresh file info for the processed file (only if different from input)
                if outputFile != file {
                    await loadFileInfo(for: outputFile)
                }
                
                // Force update of the UI to reflect changes
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
                
                // Small delay between files
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            
            statusMessage = "Batch processing completed! Files saved to: \(outputDir.lastPathComponent)"
        
        isProcessing = false
        // Force a UI update by triggering property changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Force update of computed properties
            self.objectWillChange.send()
            self.updateStatus()
        }
    }
    
    private func processVideoFile(input: URL, output: URL, fileIndex: Int, totalFiles: Int) async {
        progress = 0.0
        statusMessage = "Processing file \(fileIndex) of \(totalFiles): \(input.lastPathComponent)"
        
        do {
            let ffmpegPath = try findExecutable("ffmpeg")
            
            let attributes = try FileManager.default.attributesOfItem(atPath: input.path)
            let creationDate = attributes[.creationDate] as? Date ?? Date()
            let creationDateString = ffmpegDateFormatter.string(from: creationDate)
            
            statusMessage = "Processing \(input.lastPathComponent) with ffmpeg..."
            progress = 0.1
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpegPath)
            process.arguments = [
                "-i", input.path,
                "-c", "copy",
                "-metadata", "creation_time=\(creationDateString)",
                "-metadata", "date=\(creationDateString)",
                "-y", output.path
            ]
            
            let pipe = Pipe()
            process.standardError = pipe
            
            progress = 0.3
            statusMessage = "Running ffmpeg on \(input.lastPathComponent)..."
            
            try process.run()
            
            // Monitor progress
            let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    if let self = self, self.progress < 0.9 {
                        self.progress += 0.02
                    }
                }
            }
            
            process.waitUntilExit()
            progressTimer.invalidate()
            
            if process.terminationStatus == 0 {
                progress = 1.0
                statusMessage = "Setting file creation date for \(input.lastPathComponent)..."
                
                // Set file creation date
                do {
                    let originalCreationDate = attributes[.creationDate] as? Date ?? creationDate
                    try FileManager.default.setAttributes([
                        .creationDate: originalCreationDate,
                        .modificationDate: originalCreationDate
                    ], ofItemAtPath: output.path)
                    
                    statusMessage = "Successfully processed \(input.lastPathComponent)!"
                } catch {
                    statusMessage = "Processed \(input.lastPathComponent)! (Note: Could not set file creation date)"
                }
            } else {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "FFmpegError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorOutput])
            }
        } catch {
            progress = 0.0
            statusMessage = "Processing failed for \(input.lastPathComponent)"
            hasError = true
            showErrorAlert("Failed to process \(input.lastPathComponent): \(error.localizedDescription)")
        }
    }
    
    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showError = true
        hasError = true
    }
    
    private func findExecutable(_ name: String) throws -> String {
        if let bundlePath = Bundle.main.path(forResource: name, ofType: nil) {
            if FileManager.default.isExecutableFile(atPath: bundlePath) {
                return bundlePath
            }
        }
        
        let commonPaths = ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)", "/bin/\(name)"]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        throw NSError(domain: "ExecutableNotFound", code: 404, userInfo: [
            NSLocalizedDescriptionKey: "Could not find \(name)"
        ])
    }
}

#Preview {
    ContentView()
}
