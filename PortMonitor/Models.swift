import Foundation
import AppKit

struct PortInfo: Identifiable, Hashable {
    let id = UUID()
    let port: Int
    let protocol_: String
    let processName: String
    let pid: Int
    let user: String
    let state: ConnectionState
    let localAddress: String
    let foreignAddress: String
    let command: String          // Полная команда запуска (например: node /Users/mac/projects/myapp/server.js)
    let workingDirectory: String // Рабочая директория процесса
    let executablePath: String   // Путь к исполняемому файлу
    let bytesIn: Int64           // Байты получено
    let bytesOut: Int64          // Байты отправлено

    // Форматированный размер трафика
    var bytesInFormatted: String {
        formatBytes(bytesIn)
    }

    var bytesOutFormatted: String {
        formatBytes(bytesOut)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 0 { return "—" }
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
        return String(format: "%.2f GB", Double(bytes) / (1024 * 1024 * 1024))
    }

    // Краткое имя проекта (извлекаем из пути)
    var projectName: String {
        // Если это node/python/etc - пытаемся найти имя проекта из команды
        if let scriptPath = extractScriptPath() {
            // Берём имя папки проекта или имя файла
            let url = URL(fileURLWithPath: scriptPath)
            let parentFolder = url.deletingLastPathComponent().lastPathComponent
            if parentFolder != "/" && !parentFolder.isEmpty && parentFolder != "." {
                return parentFolder
            }
            return url.deletingPathExtension().lastPathComponent
        }

        // Если есть рабочая директория - берём её имя
        if !workingDirectory.isEmpty && workingDirectory != "/" {
            return URL(fileURLWithPath: workingDirectory).lastPathComponent
        }

        return processName
    }

    // Извлекаем путь к скрипту из команды
    private func extractScriptPath() -> String? {
        let parts = command.components(separatedBy: " ")
        // Ищем первый аргумент похожий на путь к файлу
        for part in parts.dropFirst() {
            if part.contains("/") || part.hasSuffix(".js") || part.hasSuffix(".ts") ||
               part.hasSuffix(".py") || part.hasSuffix(".rb") {
                return part
            }
        }
        return nil
    }

    var appIcon: NSImage? {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: processName).first {
            return app.icon
        }
        // Пытаемся найти приложение по имени процесса
        let workspace = NSWorkspace.shared
        if let appPath = workspace.urlForApplication(withBundleIdentifier: processName) {
            return workspace.icon(forFile: appPath.path)
        }
        // Возвращаем системную иконку
        return NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
    }

    var portCategory: PortCategory {
        switch port {
        case 80, 443, 8080, 8443:
            return .web
        case 3000, 3001, 5000, 5173, 8000, 4200:
            return .development
        case 22:
            return .ssh
        case 3306, 5432, 27017, 6379:
            return .database
        case 25, 465, 587, 993, 995:
            return .mail
        default:
            return .other
        }
    }
}

enum ConnectionState: String {
    case listen = "LISTEN"
    case established = "ESTABLISHED"
    case timeWait = "TIME_WAIT"
    case closeWait = "CLOSE_WAIT"
    case synSent = "SYN_SENT"
    case synReceived = "SYN_RECEIVED"
    case finWait1 = "FIN_WAIT_1"
    case finWait2 = "FIN_WAIT_2"
    case closing = "CLOSING"
    case lastAck = "LAST_ACK"
    case closed = "CLOSED"
    case unknown = "UNKNOWN"

    var color: String {
        switch self {
        case .listen:
            return "green"
        case .established:
            return "blue"
        case .timeWait, .closeWait, .finWait1, .finWait2:
            return "orange"
        case .closed, .closing, .lastAck:
            return "red"
        default:
            return "gray"
        }
    }

    var displayName: String {
        switch self {
        case .listen: return "Listening"
        case .established: return "Connected"
        case .timeWait: return "Time Wait"
        case .closeWait: return "Close Wait"
        case .synSent: return "SYN Sent"
        case .synReceived: return "SYN Received"
        case .finWait1: return "FIN Wait 1"
        case .finWait2: return "FIN Wait 2"
        case .closing: return "Closing"
        case .lastAck: return "Last ACK"
        case .closed: return "Closed"
        case .unknown: return "Unknown"
        }
    }
}

enum PortCategory: String, CaseIterable {
    case web = "Web"
    case development = "Development"
    case database = "Database"
    case ssh = "SSH"
    case mail = "Mail"
    case other = "Other"

    var icon: String {
        switch self {
        case .web: return "globe"
        case .development: return "hammer"
        case .database: return "cylinder"
        case .ssh: return "terminal"
        case .mail: return "envelope"
        case .other: return "questionmark.circle"
        }
    }

    var color: String {
        switch self {
        case .web: return "blue"
        case .development: return "purple"
        case .database: return "orange"
        case .ssh: return "green"
        case .mail: return "red"
        case .other: return "gray"
        }
    }
}

enum SortOption: String, CaseIterable {
    case port = "Port"
    case process = "Process"
    case state = "State"
}

enum FilterOption: String, CaseIterable {
    case all = "All"
    case listening = "Listening"
    case established = "Connected"
}
