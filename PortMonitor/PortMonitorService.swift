import Foundation
import Combine

class PortMonitorService: ObservableObject {
    @Published var ports: [PortInfo] = []
    @Published var isLoading = false
    @Published var lastUpdate: Date?
    @Published var searchText = ""
    @Published var sortOption: SortOption = .port
    @Published var filterOption: FilterOption = .all

    private var timer: Timer?

    var filteredPorts: [PortInfo] {
        var result = ports

        // Применяем фильтр
        switch filterOption {
        case .all:
            break
        case .listening:
            result = result.filter { $0.state == .listen }
        case .established:
            result = result.filter { $0.state == .established }
        }

        // Применяем поиск
        if !searchText.isEmpty {
            result = result.filter {
                $0.processName.localizedCaseInsensitiveContains(searchText) ||
                String($0.port).contains(searchText) ||
                $0.localAddress.localizedCaseInsensitiveContains(searchText) ||
                $0.command.localizedCaseInsensitiveContains(searchText) ||
                $0.projectName.localizedCaseInsensitiveContains(searchText) ||
                $0.workingDirectory.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Применяем сортировку
        switch sortOption {
        case .port:
            result.sort { $0.port < $1.port }
        case .process:
            result.sort { $0.processName.lowercased() < $1.processName.lowercased() }
        case .state:
            result.sort { $0.state.rawValue < $1.state.rawValue }
        }

        return result
    }

    var groupedByCategory: [PortCategory: [PortInfo]] {
        Dictionary(grouping: filteredPorts) { $0.portCategory }
    }

    var stats: (total: Int, listening: Int, established: Int, totalIn: Int64, totalOut: Int64) {
        let listening = ports.filter { $0.state == .listen }.count
        let established = ports.filter { $0.state == .established }.count
        let totalIn = ports.reduce(Int64(0)) { $0 + max(0, $1.bytesIn) }
        let totalOut = ports.reduce(Int64(0)) { $0 + max(0, $1.bytesOut) }
        return (ports.count, listening, established, totalIn, totalOut)
    }

    init() {
        refresh()
    }

    func refresh() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ports = self?.fetchPorts() ?? []

            DispatchQueue.main.async {
                self?.ports = ports
                self?.isLoading = false
                self?.lastUpdate = Date()
            }
        }
    }

    func startAutoRefresh(interval: TimeInterval = 5.0) {
        stopAutoRefresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    // Кэш информации о процессах (PID -> (command, cwd, execPath))
    private var processInfoCache: [Int: (command: String, cwd: String, execPath: String)] = [:]

    private func fetchPorts() -> [PortInfo] {
        var portInfos: [PortInfo] = []

        // Используем lsof для получения информации о портах
        let lsofOutput = runCommand("/usr/sbin/lsof", arguments: ["-i", "-P", "-n"])

        #if DEBUG
        print("📡 lsof output lines: \(lsofOutput.components(separatedBy: "\n").count)")
        #endif

        let lines = lsofOutput.components(separatedBy: "\n").dropFirst() // Пропускаем заголовок

        // Собираем PID для получения доп. информации
        var pidsToFetch: Set<Int> = []
        for line in lines {
            guard !line.isEmpty else { continue }
            let components = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard components.count >= 2, let pid = Int(components[1]) else { continue }
            pidsToFetch.insert(pid)
        }

        // Получаем только команды запуска (быстрая операция)
        let processInfos = fetchCommandsOnly(pids: Array(pidsToFetch))

        // Получаем статистику трафика по процессам
        let trafficStats = fetchTrafficStats()

        for line in lines {
            guard !line.isEmpty else { continue }

            let components = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

            guard components.count >= 9 else { continue }

            let processName = components[0]
            let pid = Int(components[1]) ?? 0
            let user = components[2]
            let protocolType = components[7].contains("TCP") ? "TCP" : "UDP"

            // Парсим адрес и порт
            let nameField = components[8]
            var localAddress = ""
            var foreignAddress = ""
            var port = 0
            var state: ConnectionState = .unknown

            if nameField.contains("->") {
                // Соединение установлено (TCP)
                let parts = nameField.components(separatedBy: "->")
                localAddress = parts[0]
                foreignAddress = parts.count > 1 ? parts[1] : ""
                port = Self.extractPort(from: localAddress)
            } else if nameField != "*:*" && nameField.contains(":") {
                // Listening или другое (не пустой UDP)
                localAddress = nameField
                port = Self.extractPort(from: nameField)
            }

            // Определяем состояние
            if components.count >= 10 {
                let stateStr = components[9].replacingOccurrences(of: "(", with: "")
                    .replacingOccurrences(of: ")", with: "")

                switch stateStr.uppercased() {
                case "LISTEN": state = .listen
                case "ESTABLISHED": state = .established
                case "TIME_WAIT": state = .timeWait
                case "CLOSE_WAIT": state = .closeWait
                case "SYN_SENT": state = .synSent
                case "SYN_RECEIVED": state = .synReceived
                case "FIN_WAIT_1": state = .finWait1
                case "FIN_WAIT_2": state = .finWait2
                case "CLOSING": state = .closing
                case "LAST_ACK": state = .lastAck
                case "CLOSED": state = .closed
                default: state = .unknown
                }
            }

            // Пропускаем записи без порта
            guard port > 0 else { continue }

            // Получаем дополнительную информацию о процессе
            let info = processInfos[pid] ?? (command: processName, cwd: "", execPath: "")

            // Получаем статистику трафика для этого процесса
            let traffic = trafficStats[pid] ?? (bytesIn: Int64(-1), bytesOut: Int64(-1))

            let portInfo = PortInfo(
                port: port,
                protocol_: protocolType,
                processName: processName,
                pid: pid,
                user: user,
                state: state,
                localAddress: localAddress,
                foreignAddress: foreignAddress,
                command: info.command,
                workingDirectory: info.cwd,
                executablePath: info.execPath,
                bytesIn: traffic.bytesIn,
                bytesOut: traffic.bytesOut
            )

            portInfos.append(portInfo)
        }

        // Убираем дубликаты по порту и процессу
        var seen = Set<String>()
        portInfos = portInfos.filter { info in
            let key = "\(info.port)-\(info.processName)-\(info.state.rawValue)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }

        #if DEBUG
        print("📊 Found \(portInfos.count) unique ports")
        if let first = portInfos.first {
            print("   First: port=\(first.port), process=\(first.processName), state=\(first.state)")
        }
        #endif

        return portInfos
    }

    /// Получает информацию о нескольких процессах одним запросом
    private func fetchProcessInfoBatch(pids: [Int]) -> [Int: (command: String, cwd: String, execPath: String)] {
        var result: [Int: (command: String, cwd: String, execPath: String)] = [:]

        guard !pids.isEmpty else { return result }

        // Фильтруем системные процессы (к ним обычно нет доступа)
        let userPids = pids.filter { $0 > 100 }
        guard !userPids.isEmpty else { return result }

        // Получаем команды запуска для всех PID одним вызовом ps
        let pidList = userPids.map(String.init).joined(separator: ",")
        let psOutput = runCommand("/bin/ps", arguments: ["-p", pidList, "-o", "pid=,command="])

        for line in psOutput.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Формат: "PID COMMAND..."
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count >= 2,
                  let pid = Int(parts[0]) else { continue }

            let command = String(parts[1])
            result[pid] = (command: command, cwd: "", execPath: "")
        }

        // Получаем рабочие директории через lsof -d cwd
        let cwdOutput = runCommand("/usr/sbin/lsof", arguments: ["-p", pidList, "-d", "cwd", "-Fn"])

        var currentPid: Int?
        for line in cwdOutput.components(separatedBy: "\n") {
            if line.hasPrefix("p") {
                currentPid = Int(line.dropFirst())
            } else if line.hasPrefix("n"), let pid = currentPid {
                let cwd = String(line.dropFirst())
                if var existing = result[pid] {
                    existing.cwd = cwd
                    result[pid] = existing
                } else {
                    result[pid] = (command: "", cwd: cwd, execPath: "")
                }
            }
        }

        // Получаем пути к исполняемым файлам
        let txtOutput = runCommand("/usr/sbin/lsof", arguments: ["-p", pidList, "-d", "txt", "-Fn"])

        currentPid = nil
        for line in txtOutput.components(separatedBy: "\n") {
            if line.hasPrefix("p") {
                currentPid = Int(line.dropFirst())
            } else if line.hasPrefix("n"), let pid = currentPid {
                let path = String(line.dropFirst())
                // Берём только первый txt (основной исполняемый файл)
                if var existing = result[pid], existing.execPath.isEmpty {
                    existing.execPath = path
                    result[pid] = existing
                }
            }
        }

        return result
    }

    private func runCommand(_ command: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        // Подавляем системные логи и warnings
        var env = ProcessInfo.processInfo.environment
        env["OS_ACTIVITY_MODE"] = "disable"
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    func killProcess(pid: Int) {
        let _ = runCommand("/bin/kill", arguments: ["-9", String(pid)])
        // Обновляем список после убийства процесса
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }

    /// Извлекает порт из адреса (поддержка IPv4 и IPv6)
    private static func extractPort(from address: String) -> Int {
        // Для IPv6: [fe80::1]:8080 или для IPv4: 192.168.1.1:8080 или *:8080
        if let lastColon = address.lastIndex(of: ":") {
            let portStr = String(address[address.index(after: lastColon)...])
            return Int(portStr) ?? 0
        }
        return 0
    }

    /// Быстрое получение только команд запуска
    private func fetchCommandsOnly(pids: [Int]) -> [Int: (command: String, cwd: String, execPath: String)] {
        var result: [Int: (command: String, cwd: String, execPath: String)] = [:]
        guard !pids.isEmpty else { return result }

        let userPids = pids.filter { $0 > 50 } // Фильтруем системные
        guard !userPids.isEmpty else { return result }

        let pidList = userPids.map(String.init).joined(separator: ",")
        let psOutput = runCommand("/bin/ps", arguments: ["-p", pidList, "-o", "pid=,command="])

        for line in psOutput.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count >= 2, let pid = Int(parts[0]) else { continue }

            let command = String(parts[1])
            // Пытаемся извлечь рабочую директорию из команды
            let cwd = extractWorkingDir(from: command)
            result[pid] = (command: command, cwd: cwd, execPath: "")
        }

        return result
    }

    /// Извлекает рабочую директорию из команды (эвристика)
    private func extractWorkingDir(from command: String) -> String {
        // Ищем путь в команде
        let parts = command.components(separatedBy: " ")
        for part in parts {
            if part.hasPrefix("/") && (
                part.contains("/node_modules/") ||
                part.contains("/src/") ||
                part.contains("/app/") ||
                part.hasSuffix(".js") ||
                part.hasSuffix(".ts") ||
                part.hasSuffix(".py")
            ) {
                // Берём родительскую директорию
                let url = URL(fileURLWithPath: part)
                var dir = url.deletingLastPathComponent()
                // Поднимаемся выше node_modules если есть
                if dir.lastPathComponent == "node_modules" || dir.lastPathComponent == ".bin" {
                    dir = dir.deletingLastPathComponent()
                    if dir.lastPathComponent == "node_modules" {
                        dir = dir.deletingLastPathComponent()
                    }
                }
                return dir.path
            }
        }
        return ""
    }

    /// Получает статистику трафика по процессам через nettop
    private func fetchTrafficStats() -> [Int: (bytesIn: Int64, bytesOut: Int64)] {
        var result: [Int: (bytesIn: Int64, bytesOut: Int64)] = [:]

        // nettop -P -L 1 -J bytes_in,bytes_out выводит статистику
        // Формат: process.pid,bytes_in,bytes_out
        let output = runCommand("/usr/bin/nettop", arguments: ["-P", "-L", "1", "-J", "bytes_in,bytes_out", "-x"])

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Пропускаем заголовок
            if trimmed.contains("bytes_in") && trimmed.contains("bytes_out") { continue }

            // Формат: "processname.pid,bytes_in,bytes_out" или с пробелами
            let parts = trimmed.components(separatedBy: ",")
            guard parts.count >= 3 else { continue }

            // Извлекаем PID из первой части (format: "name.123" или просто данные)
            let processField = parts[0]
            var pid: Int?

            // Ищем PID в формате "name.123"
            if let dotIndex = processField.lastIndex(of: ".") {
                let pidStr = String(processField[processField.index(after: dotIndex)...])
                pid = Int(pidStr)
            }

            guard let processPid = pid else { continue }

            let bytesIn = Int64(parts[1].trimmingCharacters(in: .whitespaces)) ?? -1
            let bytesOut = Int64(parts[2].trimmingCharacters(in: .whitespaces)) ?? -1

            result[processPid] = (bytesIn: bytesIn, bytesOut: bytesOut)
        }

        return result
    }
}
