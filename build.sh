#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

APP_NAME="PortMonitor"
SCHEME="PortMonitor"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/Export"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
DMG_TEMP="$BUILD_DIR/dmg_temp"

echo -e "${GREEN}🔨 Building $APP_NAME...${NC}"

# Очистка предыдущей сборки
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Сборка архива
echo -e "${YELLOW}📦 Creating archive...${NC}"
xcodebuild archive \
    -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -archivePath "$ARCHIVE_PATH" \
    -configuration Release \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | grep -E "(error:|warning:|BUILD|ARCHIVE)"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Archive failed${NC}"
    exit 1
fi

# Экспорт приложения
echo -e "${YELLOW}📤 Exporting app...${NC}"

# Создаём ExportOptions.plist
cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
EOF

# Копируем приложение из архива напрямую (без подписи)
mkdir -p "$EXPORT_PATH"
cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$EXPORT_PATH/"

if [ ! -d "$EXPORT_PATH/$APP_NAME.app" ]; then
    echo -e "${RED}❌ Export failed - app not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ App exported to: $EXPORT_PATH/$APP_NAME.app${NC}"

# Создание DMG
echo -e "${YELLOW}💿 Creating DMG...${NC}"

# Очистка временной папки
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Копируем приложение
cp -R "$EXPORT_PATH/$APP_NAME.app" "$DMG_TEMP/"

# Создаём симлинк на Applications
ln -s /Applications "$DMG_TEMP/Applications"

# Создаём DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_PATH"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ DMG created: $DMG_PATH${NC}"

    # Очистка
    rm -rf "$DMG_TEMP"
    rm -rf "$ARCHIVE_PATH"
    rm -f "$BUILD_DIR/ExportOptions.plist"

    # Показываем размер
    DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo -e "${GREEN}📊 DMG size: $DMG_SIZE${NC}"

    # Открываем папку с DMG
    open "$BUILD_DIR"
else
    echo -e "${RED}❌ DMG creation failed${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Build complete!${NC}"
