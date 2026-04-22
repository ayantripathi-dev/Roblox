import tkinter as tk
from tkinter import ttk, messagebox
import threading
import time
from pynput.mouse import Button, Controller
from pynput.keyboard import GlobalHotKeys

class AutoClickerApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Gaming AutoClicker")
        self.root.geometry("300x400")
        self.root.resizable(False, False)

        self.mouse = Controller()
        self.running = False
        self.interval = 0.1
        self.button = Button.left
        self.click_type = "Single"

        self.setup_gui()
        self.setup_hotkeys()
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)

    def setup_gui(self):
        main_frame = ttk.Frame(self.root, padding="20")
        main_frame.pack(expand=True, fill="both")

        # Interval
        ttk.Label(main_frame, text="Click Interval (seconds):").pack(pady=(0, 5))
        self.interval_var = tk.DoubleVar(value=0.1)
        self.interval_entry = ttk.Entry(main_frame, textvariable=self.interval_var)
        self.interval_entry.pack(pady=(0, 15))

        # Mouse Button
        ttk.Label(main_frame, text="Mouse Button:").pack(pady=(0, 5))
        self.button_var = tk.StringVar(value="Left")
        ttk.Radiobutton(main_frame, text="Left", variable=self.button_var, value="Left").pack()
        ttk.Radiobutton(main_frame, text="Right", variable=self.button_var, value="Right").pack()
        ttk.Radiobutton(main_frame, text="Middle", variable=self.button_var, value="Middle").pack(pady=(0, 15))

        # Click Type
        ttk.Label(main_frame, text="Click Type:").pack(pady=(0, 5))
        self.click_type_var = tk.StringVar(value="Single")
        ttk.Radiobutton(main_frame, text="Single", variable=self.click_type_var, value="Single").pack()
        ttk.Radiobutton(main_frame, text="Double", variable=self.click_type_var, value="Double").pack(pady=(0, 15))

        # Status
        self.status_label = ttk.Label(main_frame, text="Status: Stopped", foreground="red", font=("Helvetica", 12, "bold"))
        self.status_label.pack(pady=(10, 10))

        # Instructions
        ttk.Label(main_frame, text="Start: Cmd + Opt + S", font=("Helvetica", 10)).pack()
        ttk.Label(main_frame, text="Stop:  Cmd + Opt + P", font=("Helvetica", 10)).pack()

    def setup_hotkeys(self):
        # Hotkeys for Start: Cmd+Opt+S and Stop: Cmd+Opt+P
        self.hotkeys = GlobalHotKeys({
            '<cmd>+<alt>+s': self.start_clicking,
            '<cmd>+<alt>+p': self.stop_clicking
        })
        self.hotkeys.start()

    def _click_loop(self):
        while self.running:
            click_count = 1 if self.click_type == "Single" else 2
            self.mouse.click(self.button, click_count)
            time.sleep(self.interval)

    def start_clicking(self):
        if not self.running:
            try:
                # Update configuration from UI
                interval = self.interval_var.get()
                if interval <= 0:
                    messagebox.showerror("Error", "Interval must be greater than 0.")
                    return

                self.interval = interval
                btn_str = self.button_var.get()
                if btn_str == "Left":
                    self.button = Button.left
                elif btn_str == "Right":
                    self.button = Button.right
                else:
                    self.button = Button.middle

                self.click_type = self.click_type_var.get()

                self.running = True
                threading.Thread(target=self._click_loop, daemon=True).start()
                self.update_status_label()
            except Exception as e:
                print(f"Error starting clicker: {e}")

    def stop_clicking(self):
        if self.running:
            self.running = False
            self.update_status_label()

    def update_status_label(self):
        # Thread-safe UI update
        self.root.after(0, self._update_status_ui)

    def _update_status_ui(self):
        if self.running:
            self.status_label.config(text="Status: Running", foreground="green")
        else:
            self.status_label.config(text="Status: Stopped", foreground="red")

    def on_closing(self):
        self.stop_clicking()
        if hasattr(self, 'hotkeys'):
            self.hotkeys.stop()
        self.root.destroy()

if __name__ == "__main__":
    root = tk.Tk()
    app = AutoClickerApp(root)
    root.mainloop()
