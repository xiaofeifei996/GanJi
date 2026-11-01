# GanJi — notes for later sessions

Imported workspace (the repository builds with its own tools; Apelin has no build
description for it).

## Building
- The project is an XcodeGen project (`project.yml`) plus a GitHub Actions
  workflow that builds the `.ipa`. Xcode and XcodeGen are **not available** on
  this device, so a full app/extension build and an installable package cannot be
  produced here. `project.yml`, `Info.plist` generation and the widget's
  `NSExtension` are therefore verified by reading, not by building.
- What can be run here, with the registered toolchain and iPhoneOS SDK
  (`swiftc` is on PATH, `$SDKROOT` set):
  `swiftc -typecheck -sdk "$SDKROOT" -target arm64-apple-ios15.0 Widget/GanJiWidget.swift Shared/*.swift`
  and the same with `arm64e`. Keep the deployment target at 15.0, the project's
  own target, so an API newer than it fails the check.
- `GanJi/PlaceSearchModel.swift` does not type-check with this toolchain
  (`@preconcurrency` on the `MKLocalSearchCompleterDelegate` conformance); the
  CI toolchain accepts it. Ignore that one error when type-checking `GanJi/`.

## Rendering check for the widget (no Xcode needed)
- `WidgetKit`'s `containerBackground` renders nothing outside a widget host, so
  the widget view cannot be checked through `ImageRenderer` as a whole. Instead
  copy `Widget/GanJiWidget.swift` and `Shared/*.swift` into a scratch folder,
  strip `@main` from `GanJiWidgetBundle` and loosen `private` on `WidgetCanvas`,
  then compose `ZStack { WidgetCanvas(dark: false); GanJiWidgetView(entry:) }`
  at 158×158, 338×158 and 338×354 and render it with `ImageRenderer`
  (`renderer.uiImage?.pngData()`), sampling corner pixels afterwards.
- A program built by `swiftc` must be signed with `ldid -S<entitlements>` before
  `shell_run` can execute it; one with `@main` in a file that also has top-level
  code needs `-parse-as-library`.
- Scratch folders starting with a dot (`.apelin-check`) did not reach the file
  tools reliably; use a normal folder name and delete it afterwards.

## Widget background (iOS 26)
The illustrated background is drawn by `WidgetCanvas` and attached with
`containerBackground(for: .widget)`. On iOS 26 WidgetKit insets custom widget
content by its default `.widget` content margins and paints its own glass plate
behind it, so the canvas is clipped instead of filling the widget. Fixed with
`.contentMarginsDisabled()` and `.containerBackgroundRemovable()` on the
`StaticConfiguration` (both iOS 17+, no availability guard needed in the widget
extension, whose minimum is 15.0 through the project setting).

## Git
Remote `origin` = https://github.com/xiaofeifei996/GanJi.git (main). `git` in
`shell_run` has to run from inside the project directory; passing a two-part
absolute project path via `-C` failed.
