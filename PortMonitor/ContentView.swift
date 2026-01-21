import SwiftUI

struct ContentView: View {
    @ObservedObject var portMonitor: PortMonitorService
    @State private var hoveredPort: UUID?
    @State private var showingKillConfirmation = false
    @State private var portToKill: PortInfo?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(portMonitor: portMonitor)

            // Stats Bar
            StatsBarView(stats: portMonitor.stats)

            // Search and Filters
            SearchFilterView(portMonitor: portMonitor)

            // Content
            if portMonitor.isLoading && portMonitor.ports.isEmpty {
                LoadingView()
            } else if portMonitor.filteredPorts.isEmpty {
                EmptyStateView(searchText: portMonitor.searchText)
            } else {
                PortListView(
                    ports: portMonitor.filteredPorts,
                    hoveredPort: $hoveredPort,
                    onKill: { port in
                        portToKill = port
                        showingKillConfirmation = true
                    }
                )
            }

            // Footer
            FooterView(portMonitor: portMonitor)
        }
        .frame(width: 480, height: 560)
        .background(GlassBackground())
        .alert("Kill Process", isPresented: $showingKillConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Kill", role: .destructive) {
                if let port = portToKill {
                    portMonitor.killProcess(pid: port.pid)
                }
            }
        } message: {
            if let port = portToKill {
                Text("Are you sure you want to kill \(port.processName) (PID: \(port.pid))?")
            }
        }
    }
}

// MARK: - Glass Background (Tahoe Style)
struct GlassBackground: View {
    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.white.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Header
struct HeaderView: View {
    @ObservedObject var portMonitor: PortMonitorService

    var body: some View {
        HStack {
            Image(systemName: "network")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Port Monitor")
                .font(.system(size: 16, weight: .semibold))

            Spacer()

            Button(action: { portMonitor.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .rotationEffect(.degrees(portMonitor.isLoading ? 360 : 0))
                    .animation(
                        portMonitor.isLoading ?
                            .linear(duration: 1).repeatForever(autoreverses: false) :
                            .default,
                        value: portMonitor.isLoading
                    )
            }
            .buttonStyle(GlassButtonStyle())

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(GlassButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
    }
}

// MARK: - Stats Bar
struct StatsBarView: View {
    let stats: (total: Int, listening: Int, established: Int, totalIn: Int64, totalOut: Int64)

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
        return String(format: "%.2f GB", Double(bytes) / (1024 * 1024 * 1024))
    }

    var body: some View {
        HStack(spacing: 12) {
            StatBadge(title: "Total", value: stats.total, color: .primary)
            StatBadge(title: "Listen", value: stats.listening, color: .green)
            StatBadge(title: "Conn", value: stats.established, color: .blue)

            Spacer()

            // Общий трафик
            if stats.totalIn > 0 || stats.totalOut > 0 {
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                        Text(formatBytes(stats.totalIn))
                            .font(.system(size: 10, design: .monospaced))
                    }

                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                        Text(formatBytes(stats.totalOut))
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.1))
    }
}

struct StatBadge: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 8, height: 8)

            Text("\(value)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Search and Filter
struct SearchFilterView: View {
    @ObservedObject var portMonitor: PortMonitorService

    var body: some View {
        VStack(spacing: 8) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search ports or processes...", text: $portMonitor.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !portMonitor.searchText.isEmpty {
                    Button(action: { portMonitor.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.15))
            .cornerRadius(8)

            // Filters
            HStack(spacing: 8) {
                ForEach(FilterOption.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        isSelected: portMonitor.filterOption == filter,
                        action: { portMonitor.filterOption = filter }
                    )
                }

                Spacer()

                Menu {
                    ForEach(SortOption.allCases, id: \.self) { sort in
                        Button(action: { portMonitor.sortOption = sort }) {
                            HStack {
                                Text(sort.rawValue)
                                if portMonitor.sortOption == sort {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(portMonitor.sortOption.rawValue)
                    }
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
                .foregroundColor(isSelected ? .blue : .primary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Port List
struct PortListView: View {
    let ports: [PortInfo]
    @Binding var hoveredPort: UUID?
    let onKill: (PortInfo) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(ports) { port in
                    PortRowView(
                        port: port,
                        isHovered: hoveredPort == port.id,
                        onKill: { onKill(port) }
                    )
                    .onHover { isHovered in
                        hoveredPort = isHovered ? port.id : nil
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

struct PortRowView: View {
    let port: PortInfo
    let isHovered: Bool
    let onKill: () -> Void
    @State private var isExpanded = false

    var stateColor: Color {
        switch port.state {
        case .listen: return .green
        case .established: return .blue
        case .timeWait, .closeWait, .finWait1, .finWait2: return .orange
        case .closed, .closing, .lastAck: return .red
        default: return .gray
        }
    }

    var categoryColor: Color {
        switch port.portCategory {
        case .web: return .blue
        case .development: return .purple
        case .database: return .orange
        case .ssh: return .green
        case .mail: return .red
        case .other: return .gray
        }
    }

    // Показываем projectName если он отличается от processName
    var displayName: String {
        if port.projectName != port.processName && !port.projectName.isEmpty {
            return port.projectName
        }
        return port.processName
    }

    // Краткое описание что запущено
    var shortDescription: String {
        let cmd = port.command.lowercased()
        let name = port.processName.lowercased()

        // Node.js / JavaScript
        if name == "node" || name == "bun" || name == "deno" {
            if cmd.contains("vite") { return "Vite dev server" }
            if cmd.contains("next") { return "Next.js" }
            if cmd.contains("nuxt") { return "Nuxt.js" }
            if cmd.contains("remix") { return "Remix" }
            if cmd.contains("astro") { return "Astro" }
            if cmd.contains("svelte") || cmd.contains("sveltekit") { return "SvelteKit" }
            if cmd.contains("react-scripts") { return "Create React App" }
            if cmd.contains("webpack") { return "Webpack" }
            if cmd.contains("esbuild") { return "esbuild" }
            if cmd.contains("parcel") { return "Parcel" }
            if cmd.contains("rollup") { return "Rollup" }
            if cmd.contains("express") { return "Express.js" }
            if cmd.contains("fastify") { return "Fastify" }
            if cmd.contains("koa") { return "Koa.js" }
            if cmd.contains("nest") { return "NestJS" }
            if cmd.contains("strapi") { return "Strapi CMS" }
            if cmd.contains("prisma") { return "Prisma Studio" }
            if cmd.contains("storybook") { return "Storybook" }
            if cmd.contains("electron") { return "Electron app" }
            if cmd.contains("turbo") { return "Turborepo" }
            if cmd.contains("angular") || cmd.contains("ng serve") { return "Angular" }
            if cmd.contains("server") || cmd.contains("app.js") || cmd.contains("index.js") {
                return "Node.js server"
            }
            return "Node.js"
        }

        // Python
        if name == "python" || name == "python3" || name.hasPrefix("python") {
            if cmd.contains("django") || cmd.contains("manage.py") { return "Django" }
            if cmd.contains("flask") { return "Flask" }
            if cmd.contains("uvicorn") { return "Uvicorn (ASGI)" }
            if cmd.contains("fastapi") { return "FastAPI" }
            if cmd.contains("gunicorn") { return "Gunicorn" }
            if cmd.contains("streamlit") { return "Streamlit" }
            if cmd.contains("jupyter") { return "Jupyter" }
            if cmd.contains("celery") { return "Celery worker" }
            if cmd.contains("airflow") { return "Apache Airflow" }
            return "Python"
        }

        // Ruby
        if name == "ruby" || name == "puma" || name == "unicorn" {
            if cmd.contains("rails") { return "Ruby on Rails" }
            if cmd.contains("sinatra") { return "Sinatra" }
            if cmd.contains("puma") { return "Puma server" }
            return "Ruby"
        }

        // PHP
        if name == "php" || name == "php-fpm" {
            if cmd.contains("artisan") { return "Laravel" }
            if cmd.contains("symfony") { return "Symfony" }
            return "PHP"
        }

        // Go
        if name == "go" || cmd.contains("/go/") {
            return "Go application"
        }

        // Rust
        if name == "cargo" || cmd.contains("cargo run") {
            return "Rust application"
        }

        // Java / JVM
        if name == "java" || name.contains("java") {
            if cmd.contains("spring") { return "Spring Boot" }
            if cmd.contains("tomcat") { return "Apache Tomcat" }
            if cmd.contains("jetty") { return "Jetty" }
            if cmd.contains("gradle") { return "Gradle" }
            if cmd.contains("maven") { return "Maven" }
            return "Java application"
        }

        // Databases
        if name == "postgres" || name == "postgresql" { return "PostgreSQL" }
        if name == "mysqld" || name == "mysql" { return "MySQL" }
        if name == "mongod" || name == "mongodb" { return "MongoDB" }
        if name == "redis-server" || name == "redis" { return "Redis" }
        if name == "memcached" { return "Memcached" }
        if name == "clickhouse" { return "ClickHouse" }
        if name == "elasticsearch" { return "Elasticsearch" }

        // Web servers
        if name == "nginx" { return "Nginx" }
        if name == "httpd" || name == "apache2" { return "Apache HTTP" }
        if name == "caddy" { return "Caddy" }
        if name == "traefik" { return "Traefik" }

        // Containers & DevOps
        if name == "docker" || name.contains("docker") { return "Docker" }
        if name == "containerd" { return "containerd" }
        if name == "kubectl" { return "Kubernetes CLI" }

        // Apple system services
        if name == "identityservicesd" || name == "identitys" { return "Apple Identity Services" }
        if name == "rapportd" { return "AirPlay/Handoff" }
        if name == "sharingd" { return "Sharing Daemon" }
        if name == "controlce" || name == "controlcenter" { return "Control Center" }
        if name == "airplayxpcd" || name.contains("airplay") { return "AirPlay" }
        if name == "screensharingd" { return "Screen Sharing" }
        if name == "sshd" || name == "ssh" { return "SSH Server" }
        if name == "remotepairingd" { return "Remote Pairing" }
        if name == "apsd" { return "Apple Push Service" }
        if name == "mDNSResponder" || name == "mdnsresponder" { return "Bonjour/mDNS" }
        if name == "netbiosd" { return "NetBIOS" }
        if name == "smbd" { return "SMB File Sharing" }
        if name == "cupsd" { return "CUPS Printing" }
        if name == "launchd" { return "macOS Launcher" }

        // Browsers
        if name.contains("safari") { return "Safari" }
        if name.contains("chrome") || name.contains("chromium") { return "Chrome" }
        if name.contains("firefox") { return "Firefox" }
        if name.contains("arc") { return "Arc Browser" }
        if name.contains("edge") { return "Microsoft Edge" }
        if name.contains("brave") { return "Brave" }
        if name.contains("opera") { return "Opera" }

        // IDEs & Editors
        if name.contains("code") && name.contains("helper") { return "VS Code" }
        if name.contains("cursor") { return "Cursor IDE" }
        if name.contains("webstorm") { return "WebStorm" }
        if name.contains("intellij") { return "IntelliJ IDEA" }
        if name.contains("pycharm") { return "PyCharm" }
        if name.contains("sublime") { return "Sublime Text" }
        if name.contains("atom") { return "Atom" }

        // Messaging & Apps
        if name.contains("slack") { return "Slack" }
        if name.contains("discord") { return "Discord" }
        if name.contains("telegram") { return "Telegram" }
        if name.contains("zoom") { return "Zoom" }
        if name.contains("teams") { return "Microsoft Teams" }
        if name.contains("spotify") { return "Spotify" }
        if name.contains("dropbox") { return "Dropbox" }
        if name.contains("1password") { return "1Password" }

        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Основная строка
            HStack(spacing: 12) {
                // Port number with category indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryColor.opacity(0.2))
                        .frame(width: 60, height: 40)

                    VStack(spacing: 2) {
                        Text("\(port.port)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))

                        Text(port.protocol_)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                // Process info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if let icon = port.appIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 18, height: 18)
                        }

                        // Имя проекта/процесса
                        Text(displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        // Показываем имя процесса если отличается
                        if port.projectName != port.processName && !port.projectName.isEmpty {
                            Text("(\(port.processName))")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        // Описание процесса
                        if !shortDescription.isEmpty {
                            Text("• \(shortDescription)")
                                .font(.system(size: 11))
                                .foregroundColor(.cyan)
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("PID: \(port.pid)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        // Категория порта
                        HStack(spacing: 3) {
                            Image(systemName: port.portCategory.icon)
                                .font(.system(size: 8))
                            Text(port.portCategory.rawValue)
                                .font(.system(size: 9))
                        }
                        .foregroundColor(categoryColor.opacity(0.8))

                        // Статистика трафика (если есть)
                        if port.bytesIn >= 0 || port.bytesOut >= 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 8))
                                    .foregroundColor(.green)
                                Text(port.bytesInFormatted)
                                    .font(.system(size: 9, design: .monospaced))

                                Image(systemName: "arrow.up")
                                    .font(.system(size: 8))
                                    .foregroundColor(.orange)
                                Text(port.bytesOutFormatted)
                                    .font(.system(size: 9, design: .monospaced))
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // State badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(stateColor)
                        .frame(width: 6, height: 6)

                    Text(port.state.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(stateColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(stateColor.opacity(0.15))
                .cornerRadius(10)

                // Expand button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                // Kill button (shown on hover)
                if isHovered {
                    Button(action: onKill) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Kill process")
                }
            }

            // Раскрывающаяся секция с деталями
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                        .padding(.vertical, 4)

                    // Команда запуска
                    if !port.command.isEmpty {
                        DetailRow(icon: "terminal", label: "Command", value: port.command)
                    }

                    // Рабочая директория
                    if !port.workingDirectory.isEmpty {
                        DetailRow(icon: "folder", label: "Directory", value: port.workingDirectory)
                    }

                    // Путь к исполняемому файлу
                    if !port.executablePath.isEmpty {
                        DetailRow(icon: "doc", label: "Executable", value: port.executablePath)
                    }

                    // Адреса
                    if !port.localAddress.isEmpty {
                        DetailRow(icon: "arrow.right", label: "Local", value: port.localAddress)
                    }
                    if !port.foreignAddress.isEmpty {
                        DetailRow(icon: "arrow.left", label: "Remote", value: port.foreignAddress)
                    }

                    // Статистика трафика
                    if port.bytesIn >= 0 || port.bytesOut >= 0 {
                        Divider()
                            .padding(.vertical, 2)

                        HStack(spacing: 20) {
                            // Входящий трафик
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Received")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    Text(port.bytesInFormatted)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                }
                            }

                            // Исходящий трафик
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Sent")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    Text(port.bytesOutFormatted)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 66) // Выравнивание под основной контент
                .padding(.trailing, 10)
                .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isHovered || isExpanded ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture {
            isExpanded.toggle()
        }
    }
}

// Строка с деталями
struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .frame(width: 12)

            Text(label + ":")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary.opacity(0.8))
                .lineLimit(2)
                .textSelection(.enabled)

            Spacer()

            // Кнопка копирования
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")
        }
    }
}

// MARK: - Empty & Loading States
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Scanning ports...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: searchText.isEmpty ? "network.slash" : "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text(searchText.isEmpty ? "No active ports found" : "No results for \"\(searchText)\"")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Footer
struct FooterView: View {
    @ObservedObject var portMonitor: PortMonitorService

    var body: some View {
        HStack {
            if let lastUpdate = portMonitor.lastUpdate {
                Text("Updated \(lastUpdate.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "info.circle")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Text("Click port to copy")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.1))
    }
}

// MARK: - Button Styles
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(configuration.isPressed ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
