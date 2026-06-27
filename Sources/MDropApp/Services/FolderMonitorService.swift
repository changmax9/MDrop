import Darwin
import Foundation
import MDropCore

@MainActor
final class FolderMonitorService {
    private final class Monitor {
        let definition: WatchFolderDefinition
        let descriptor: Int32
        let source: DispatchSourceFileSystemObject
        var seenPaths: Set<String>

        init(
            definition: WatchFolderDefinition,
            descriptor: Int32,
            source: DispatchSourceFileSystemObject,
            seenPaths: Set<String>
        ) {
            self.definition = definition
            self.descriptor = descriptor
            self.source = source
            self.seenPaths = seenPaths
        }
    }

    private var monitors: [UUID: Monitor] = [:]
    private var debounceTasks: [UUID: Task<Void, Never>] = [:]
    private let onNewFiles: (WatchFolderDefinition, [URL]) -> Void

    init(onNewFiles: @escaping (WatchFolderDefinition, [URL]) -> Void) {
        self.onNewFiles = onNewFiles
    }

    func update(_ definitions: [WatchFolderDefinition]) {
        stop()
        for definition in definitions where definition.isEnabled {
            start(definition)
        }
    }

    func stop() {
        debounceTasks.values.forEach { $0.cancel() }
        debounceTasks.removeAll()
        monitors.values.forEach { $0.source.cancel() }
        monitors.removeAll()
    }

    private func start(_ definition: WatchFolderDefinition) {
        let descriptor = open(definition.url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .extend],
            queue: .main
        )
        let monitor = Monitor(
            definition: definition,
            descriptor: descriptor,
            source: source,
            seenPaths: currentPaths(for: definition)
        )
        monitors[definition.id] = monitor
        source.setEventHandler { [weak self] in
            self?.scheduleScan(definition.id)
        }
        source.setCancelHandler {
            Darwin.close(descriptor)
        }
        source.resume()
    }

    private func scheduleScan(_ id: UUID) {
        debounceTasks[id]?.cancel()
        debounceTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            self?.scan(id)
        }
    }

    private func scan(_ id: UUID) {
        guard let monitor = monitors[id] else { return }
        let current = currentPaths(for: monitor.definition)
        let newPaths = current.subtracting(monitor.seenPaths).sorted()
        monitor.seenPaths = current
        guard !newPaths.isEmpty else { return }
        onNewFiles(
            monitor.definition,
            newPaths.map { URL(filePath: $0) }
        )
    }

    private func currentPaths(
        for definition: WatchFolderDefinition
    ) -> Set<String> {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: definition.url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsSubdirectoryDescendants]
        )) ?? []
        return Set(
            urls.filter(definition.rule.matches).map(\.standardizedFileURL.path)
        )
    }
}
