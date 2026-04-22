# Gaming AutoClicker for macOS

A standalone auto-clicker application for macOS with global hotkeys.

## Features
- Global Hotkeys:
  - **Start:** `Cmd + Opt + S`
  - **Stop:** `Cmd + Opt + P`
- Customizable click interval (in seconds).
- Selectable mouse buttons (Left, Right, Middle).
- Support for Single and Double clicks.
- Clean GUI for easy configuration.

## Prerequisites
- macOS
- Python 3.x

## Installation & Setup

1. **Install Dependencies:**
   Open your terminal and run:
   ```bash
   pip install -r requirements.txt
   ```

2. **Grant Accessibility Permissions:**
   For the auto-clicker to control your mouse, you must grant it accessibility permissions:
   - Go to **System Settings** > **Privacy & Security** > **Accessibility**.
   - Add and enable your Terminal (if running via script) or the "Gaming AutoClicker" app (if running as a bundle).

## Running the Script
To run the auto-clicker directly:
```bash
python3 autoclicker.py
```

## Building as a Standalone .app Bundle

To create a native macOS application bundle:

1. **Install py2app:**
   ```bash
   pip install py2app
   ```

2. **Build the App:**
   ```bash
   python3 setup.py py2app
   ```
   The `.app` file will be generated in the `dist/` directory.

## Usage
1. Open the application.
2. Set your desired click interval and mouse settings in the GUI.
3. Use the global hotkeys (`Cmd + Opt + S` to start, `Cmd + Opt + P` to stop) to control the clicker while in your game.
