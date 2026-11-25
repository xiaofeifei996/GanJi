#!/bin/bash
set -euo pipefail
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
ARCH=$(uname -m)
DEVICE=$(xcrun simctl list devices available -j | python3 -c 'import sys,json; d=json.load(sys.stdin); print(next(v["udid"] for k,items in d["devices"].items() if "iOS" in k for v in items if v["isAvailable"] and "iPhone" in v["name"]))')
xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun swiftc -sdk "$SDK" -target "$ARCH-apple-ios16.0-simulator" Shared/LunarCalendar.swift Shared/WidgetSharedStorage.swift Shared/WidgetFeed.swift Shared/WidgetBackground.swift Tests/WidgetBackgroundTests.swift -o /tmp/widget-background-tests
xcrun simctl spawn "$DEVICE" /tmp/widget-background-tests
xcrun swiftc -sdk "$SDK" -target "$ARCH-apple-ios16.0-simulator" Shared/LunarCalendar.swift Shared/WidgetSharedStorage.swift Shared/WidgetFeed.swift Shared/WidgetBackground.swift GanJi/WidgetAppearanceEditor.swift Tests/WidgetAppearanceEditorTests.swift -o /tmp/widget-appearance-editor-tests
xcrun simctl spawn "$DEVICE" /tmp/widget-appearance-editor-tests
xcrun swiftc -sdk "$SDK" -target "$ARCH-apple-ios16.0-simulator" Shared/LunarCalendar.swift Shared/WidgetSharedStorage.swift Shared/WidgetFeed.swift Widget/WidgetProvider.swift GanJi/WidgetAppearanceSnapshot.swift Tests/WidgetAppearanceSnapshotTests.swift -o /tmp/widget-appearance-snapshot-tests
xcrun simctl spawn "$DEVICE" /tmp/widget-appearance-snapshot-tests
xcrun swiftc -sdk "$SDK" -target "$ARCH-apple-ios16.0-simulator" Shared/LunarCalendar.swift Shared/WidgetSharedStorage.swift Shared/WidgetFeed.swift Shared/WidgetBackground.swift Widget/WidgetProvider.swift Widget/WidgetLook.swift Widget/WidgetBoards.swift Tests/WidgetRenderChecks.swift -o /tmp/widget-render-checks
mkdir -p "$PWD/widget-renders"
xcrun simctl spawn "$DEVICE" /tmp/widget-render-checks "$PWD/widget-renders"
