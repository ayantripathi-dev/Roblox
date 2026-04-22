import sys
from unittest.mock import MagicMock

# Mock pynput and tkinter to test logic in headless environment
sys.modules['pynput'] = MagicMock()
sys.modules['pynput.mouse'] = MagicMock()
sys.modules['pynput.keyboard'] = MagicMock()
sys.modules['tkinter'] = MagicMock()
sys.modules['tkinter.ttk'] = MagicMock()
sys.modules['tkinter.messagebox'] = MagicMock()

from mac_autoclicker.autoclicker import AutoClickerApp

def test_logic():
    root = MagicMock()
    app = AutoClickerApp(root)

    # Mock GUI variables
    app.interval_var = MagicMock()
    app.interval_var.get.return_value = 0.5
    app.button_var = MagicMock()
    app.button_var.get.return_value = "Left"
    app.click_type_var = MagicMock()
    app.click_type_var.get.return_value = "Single"
    app.status_label = MagicMock()

    print("Testing start_clicking...")
    app.start_clicking()
    assert app.running == True
    assert app.interval == 0.5
    print("start_clicking passed.")

    print("Testing stop_clicking...")
    app.stop_clicking()
    assert app.running == False
    print("stop_clicking passed.")

if __name__ == "__main__":
    try:
        test_logic()
        print("All logic tests passed!")
    except Exception as e:
        print(f"Tests failed: {e}")
        sys.exit(1)
