# Port Monitor

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Что это такое?

Port Monitor — это маленькое приложение для macOS, которое живёт в меню-баре (там, где часы и Wi-Fi) и показывает, какие программы на вашем компьютере используют сетевые порты.

### Зачем это нужно?

Если вы разработчик, наверняка сталкивались с ситуацией: запускаете проект, а порт 3000 уже занят. Кем? Непонятно. Приходится лезть в терминал, писать `lsof -i :3000`, разбираться в выводе...

Port Monitor решает эту проблему — один клик по иконке в меню-баре, и вы видите:
- Какие порты заняты
- Какими приложениями (причём не просто "node", а "Vite dev server" или "Next.js")
- Сколько трафика идёт через каждый порт
- Можно тут же убить ненужный процесс

### Что умеет приложение

**Показывает понятные названия процессов.** Вместо cryptic "node" или "python3" вы увидите "Next.js", "Django", "Express.js", "PostgreSQL" и так далее. Приложение распознаёт 50+ популярных фреймворков и сервисов.

**Отслеживает трафик.** Видно, сколько данных получено и отправлено через каждый порт — полезно, чтобы понять, какой процесс активно качает данные.

**Фильтрует и ищет.** Можно быстро найти нужный порт по номеру, имени процесса или проекту.

**Убивает процессы.** Наведите на строку и нажмите крестик — процесс будет завершён. Удобно, когда нужно освободить порт.

**Выглядит нативно.** Интерфейс в стиле macOS с полупрозрачным фоном — приложение выглядит как часть системы, а не инородное тело.

### Какие процессы распознаёт

- **JavaScript/Node.js:** Vite, Next.js, Nuxt, Express, NestJS, Angular, React, Webpack и др.
- **Python:** Django, Flask, FastAPI, Uvicorn, Gunicorn, Jupyter, Streamlit
- **Ruby:** Rails, Sinatra, Puma
- **PHP:** Laravel, Symfony
- **Базы данных:** PostgreSQL, MySQL, MongoDB, Redis, Elasticsearch
- **Веб-серверы:** Nginx, Apache, Caddy
- **Системные сервисы macOS:** AirPlay, Handoff, Screen Sharing, SSH и др.
- **Браузеры и приложения:** Chrome, Safari, VS Code, Slack, Discord, Telegram и др.

## Скриншоты

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
