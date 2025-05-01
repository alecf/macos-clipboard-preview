# Clipboard Preview

A modern macOS app that monitors your clipboard and provides instant previews of copied content with formatting support.

## Features

- Real-time clipboard monitoring
- Automatic content type detection
- Support for multiple formats:
  - JSON (with pretty printing)
  - HTML (with rendering)
  - CSS (with formatting)
  - Markdown (with HTML preview)
- Two-tab interface:
  - Preview: Shows the content as it would appear
  - Formatted: Shows the prettified/formatted version
- Menu bar integration
- Copy formatted content back to clipboard

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Building the App

1. Clone the repository
2. Open Terminal and navigate to the project directory
3. Run `swift build` to build the app
4. Run `swift run` to launch the app

## Usage

1. The app runs in the background with a menu bar icon
2. Copy any content to your clipboard
3. A preview window will automatically appear with two tabs:
   - Preview: Shows the content as it would appear
   - Formatted: Shows the prettified version
4. Use the "Copy" button in the Formatted tab to copy the formatted content back to your clipboard
5. Click the menu bar icon to access the quit option

## Dependencies

- [SwiftSoup](https://github.com/scinfu/SwiftSoup): HTML parsing and formatting
- [Down](https://github.com/johnxnguyen/Down): Markdown processing

## License

MIT License
