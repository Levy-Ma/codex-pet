from __future__ import annotations

import math
import sys
import tkinter as tk

from desktop_pet.state import ensure_state_file, read_state

TRANSPARENT = "#ff00ff"
INK = "#08080a"
INK_SOFT = "#111218"
HIGHLIGHT = "#f7fbff"
GREEN = "#54d17a"
BLUE = "#65a9ff"
RED = "#ff6b6b"
GOLD = "#f7c948"


class CodexPetApp:
    def __init__(self) -> None:
        self.root = tk.Tk()
        self.root.title("Codex Pet")
        self.root.geometry("240x190+80+160")
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)
        self.root.configure(bg=TRANSPARENT)
        try:
            self.root.attributes("-transparentcolor", TRANSPARENT)
        except tk.TclError:
            self.root.attributes("-alpha", 0.94)

        self.canvas = tk.Canvas(
            self.root,
            width=240,
            height=190,
            bg=TRANSPARENT,
            highlightthickness=0,
            bd=0,
        )
        self.canvas.pack(fill="both", expand=True)

        self.state_path = ensure_state_file()
        self.last_mtime = 0.0
        self.state = read_state()
        self.tick = 0
        self.drag_offset = (0, 0)

        self.canvas.bind("<ButtonPress-1>", self.start_drag)
        self.canvas.bind("<B1-Motion>", self.drag)
        self.canvas.bind("<Double-Button-1>", lambda _event: self.root.destroy())
        self.root.bind("<Escape>", lambda _event: self.root.destroy())

    def start_drag(self, event: tk.Event) -> None:
        self.drag_offset = (event.x, event.y)

    def drag(self, event: tk.Event) -> None:
        x = self.root.winfo_x() + event.x - self.drag_offset[0]
        y = self.root.winfo_y() + event.y - self.drag_offset[1]
        self.root.geometry(f"+{x}+{y}")

    def poll_state(self) -> None:
        try:
            mtime = self.state_path.stat().st_mtime
        except OSError:
            ensure_state_file()
            mtime = 0.0
        if mtime != self.last_mtime:
            self.last_mtime = mtime
            self.state = read_state()

    def draw(self) -> None:
        self.poll_state()
        self.canvas.delete("all")
        state = self.state["state"]
        phase = self.tick / 10
        bob = math.sin(phase) * (1 if state == "sleeping" else 3)
        breathe = math.sin(phase * 0.8) * 2
        tail = math.sin(phase * 1.4) * 8
        blink = self.tick % 72 in (0, 1, 2) and state not in {"sleeping", "error"}

        self.draw_shadow(bob)
        self.draw_tail(tail, bob, state)
        self.draw_body(breathe, bob, state)
        self.draw_head(bob, state)
        self.draw_face(blink, bob, state)
        self.draw_status_effects(state, phase, bob)
        self.draw_caption(state)

        self.tick += 1
        self.root.after(50, self.draw)

    def draw_shadow(self, bob: float) -> None:
        self.canvas.create_oval(62, 158, 178, 174, fill="#1a1a1d", outline="", stipple="gray50")

    def draw_tail(self, tail: float, bob: float, state: str) -> None:
        color = INK_SOFT if state != "success" else "#101612"
        points = [
            150,
            122 + bob,
            194,
            104 + bob - tail,
            184,
            68 + bob - tail / 2,
            154,
            82 + bob,
        ]
        self.canvas.create_line(points, fill=color, width=18, smooth=True, capstyle=tk.ROUND)
        self.canvas.create_line(points, fill=INK, width=12, smooth=True, capstyle=tk.ROUND)

    def draw_body(self, breathe: float, bob: float, state: str) -> None:
        y = 108 + bob
        self.canvas.create_oval(74, y - 4, 164, 166 + breathe, fill=INK, outline=INK_SOFT, width=2)
        self.canvas.create_oval(93, y + 28, 112, 167, fill="#050506", outline="")
        self.canvas.create_oval(128, y + 28, 147, 167, fill="#050506", outline="")
        if state == "success":
            self.canvas.create_arc(92, y + 18, 146, y + 56, start=200, extent=140, outline=GREEN, width=3, style=tk.ARC)

    def draw_head(self, bob: float, state: str) -> None:
        y = 72 + bob
        ear_l = [75, y + 8, 91, y - 34, 111, y + 7]
        ear_r = [129, y + 7, 151, y - 34, 165, y + 10]
        self.canvas.create_polygon(ear_l, fill=INK, outline=INK_SOFT, width=2)
        self.canvas.create_polygon(ear_r, fill=INK, outline=INK_SOFT, width=2)
        self.canvas.create_polygon(86, y + 2, 94, y - 18, 103, y + 5, fill="#1d1d24", outline="")
        self.canvas.create_polygon(139, y + 5, 149, y - 18, 156, y + 3, fill="#1d1d24", outline="")
        self.canvas.create_oval(70, y - 4, 170, y + 78, fill=INK, outline=INK_SOFT, width=2)
        if state == "error":
            self.canvas.create_arc(77, y, 163, y + 74, start=40, extent=100, outline=RED, width=3, style=tk.ARC)

    def draw_face(self, blink: bool, bob: float, state: str) -> None:
        y = 72 + bob
        eye_color = GOLD if state != "sleeping" else "#2b2b31"
        if state == "sleeping":
            self.canvas.create_arc(92, y + 30, 111, y + 42, start=200, extent=140, outline=HIGHLIGHT, width=2, style=tk.ARC)
            self.canvas.create_arc(130, y + 30, 149, y + 42, start=200, extent=140, outline=HIGHLIGHT, width=2, style=tk.ARC)
        elif blink:
            self.canvas.create_line(91, y + 36, 111, y + 35, fill=HIGHLIGHT, width=2)
            self.canvas.create_line(130, y + 35, 150, y + 36, fill=HIGHLIGHT, width=2)
        else:
            self.canvas.create_oval(91, y + 25, 112, y + 48, fill=eye_color, outline="")
            self.canvas.create_oval(130, y + 25, 151, y + 48, fill=eye_color, outline="")
            self.canvas.create_oval(100, y + 29, 107, y + 45, fill="#090909", outline="")
            self.canvas.create_oval(139, y + 29, 146, y + 45, fill="#090909", outline="")
            self.canvas.create_oval(96, y + 28, 100, y + 32, fill=HIGHLIGHT, outline="")
            self.canvas.create_oval(135, y + 28, 139, y + 32, fill=HIGHLIGHT, outline="")
        self.canvas.create_polygon(119, y + 48, 123, y + 52, 115, y + 52, fill="#2c2c34", outline="")
        self.canvas.create_arc(108, y + 50, 121, y + 61, start=300, extent=90, outline=HIGHLIGHT, width=1, style=tk.ARC)
        self.canvas.create_arc(119, y + 50, 132, y + 61, start=150, extent=90, outline=HIGHLIGHT, width=1, style=tk.ARC)

    def draw_status_effects(self, state: str, phase: float, bob: float) -> None:
        if state == "thinking":
            for idx in range(3):
                r = 3 + ((self.tick + idx * 8) % 18) / 8
                x = 178 + idx * 14
                y = 44 - math.sin(phase + idx) * 5
                self.canvas.create_oval(x - r, y - r, x + r, y + r, fill=BLUE, outline="")
        elif state == "success":
            self.canvas.create_text(185, 44 + bob, text="✓", fill=GREEN, font=("Helvetica", 28, "bold"))
            self.canvas.create_oval(51, 42, 57, 48, fill=GREEN, outline="")
        elif state == "error":
            self.canvas.create_text(184, 46 + bob, text="!", fill=RED, font=("Helvetica", 30, "bold"))
        elif state == "sleeping":
            self.canvas.create_text(178, 48, text="Z", fill=BLUE, font=("Helvetica", 20, "bold"))
            self.canvas.create_text(194, 34, text="z", fill=BLUE, font=("Helvetica", 14, "bold"))

    def draw_caption(self, state: str) -> None:
        labels = {
            "idle": "ready",
            "thinking": "thinking",
            "success": "done",
            "error": "attention",
            "sleeping": "resting",
        }
        self.canvas.create_text(
            120,
            181,
            text=labels.get(state, "ready"),
            fill="#f5f7fa",
            font=("Helvetica", 11, "bold"),
        )

    def run(self) -> None:
        self.draw()
        self.root.mainloop()


def main() -> int:
    try:
        CodexPetApp().run()
    except tk.TclError as exc:
        print(f"Unable to start desktop window: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
