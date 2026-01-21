# Port Monitor

A beautiful macOS menu bar application for monitoring network ports and connections.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Menu Bar App** - Lives in your menu bar, no dock icon clutter
- **Real-time Monitoring** - View all active network connections and listening ports
- **Process Identification** - See which apps are using which ports with smart process detection
- **Traffic Statistics** - Monitor incoming/outgoing traffic per process
- **Smart Descriptions** - Automatic recognition of popular frameworks and services:
  - Node.js (Vite, Next.js, Express, NestJS, etc.)
  - Python (Django, Flask, FastAPI, etc.)
  - Databases (PostgreSQL, MySQL, MongoDB, Redis)
  - Apple Services (Identity Services, AirPlay, Sharing)
  - And many more...
- **macOS Tahoe Style** - Beautiful glassmorphism UI with transparency effects
- **Search & Filter** - Quickly find ports by name, number, or process
- **Kill Process** - Terminate processes directly from the app

## Screenshots

<img src="screenshot.png" width="480" alt="Port Monitor Screenshot">

## Installation

### Download DMG
Download the latest release from the [Releases](../../releases) page.

### Build from Source
1. Clone the repository
   ```bash
   git clone https://github.com/hyattmatthew/PortMonitor.git
   cd PortMonitor
   ```

2. Open in Xcode
   ```bash
   open PortMonitor.xcodeproj
   ```

3. Build and run (⌘+R)

### Build DMG
```bash
./build.sh
```

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac

## Usage

1. Click the network icon in the menu bar
2. View all active ports and connections
3. Use search to filter by port number, process name, or project
4. Click on a row to expand and see detailed information
5. Hover and click the X button to kill a process

## Tech Stack

- **SwiftUI** - Modern declarative UI
- **AppKit** - Menu bar integration
- **lsof** - Port and process information
- **nettop** - Network traffic statistics

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Pull requests are welcome! For major changes, please open an issue first.
