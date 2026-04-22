from setuptools import setup

APP = ['autoclicker.py']
DATA_FILES = []
OPTIONS = {
    'argv_emulation': True,
    'packages': ['pynput', 'tkinter'],
    'plist': {
        'CFBundleName': 'GamingAutoClicker',
        'CFBundleDisplayName': 'Gaming AutoClicker',
        'CFBundleIdentifier': 'com.gaming.autoclicker',
        'CFBundleVersion': '0.1.0',
        'CFBundleShortVersionString': '0.1.0',
        'NSAppleEventsUsageDescription': 'This app needs to control your mouse for auto-clicking.',
    }
}

setup(
    app=APP,
    data_files=DATA_FILES,
    options={'py2app': OPTIONS},
    setup_requires=['py2app'],
)
