#!/usr/bin/env python3
"""Keypress-to-redraw latency of glassterm's toggle, measured end to end.

Starts Neovim with only this plugin inside a real pseudo-terminal, waits for
the pre-started shell, then presses Alt-t repeatedly and times how long
Neovim takes to finish redrawing after each press. The terminal emulator's
own paint is not included.

    python3 scripts/bench.py [--toggles 40] [--max-median-ms 5] [--size 230x62]

Exits non-zero when the median exceeds --max-median-ms.
"""

import argparse
import fcntl
import os
import pty
import select
import statistics
import struct
import sys
import tempfile
import termios
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

INIT = """
vim.opt.runtimepath:prepend(%r)
vim.o.swapfile = false
require("glassterm").setup({ shell = { "/bin/sh" }, prewarm = { delay_ms = 0 } })
vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn.readfile(%r))
"""


def drain(fd, quiet, limit):
    """Read until output has been quiet for `quiet` seconds."""
    start = time.perf_counter()
    first = last = None
    while time.perf_counter() - start < limit:
        ready, _, _ = select.select([fd], [], [], quiet)
        if not ready:
            if first is not None:
                break
            continue
        try:
            os.read(fd, 1 << 20)
        except OSError:
            break
        now = time.perf_counter()
        first = first or now
        last = now
    return first, last


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--toggles", type=int, default=40)
    ap.add_argument("--max-median-ms", type=float, default=5.0)
    ap.add_argument("--size", default="230x62")
    args = ap.parse_args()
    cols, rows = (int(n) for n in args.size.split("x"))

    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as f:
        f.write(INIT % (ROOT, os.path.join(ROOT, "lua", "glassterm", "window.lua")))
        init = f.name

    pid, fd = pty.fork()
    if pid == 0:
        os.environ["TERM"] = "xterm-256color"
        os.execvp("nvim", ["nvim", "--clean", "-u", init])
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))

    try:
        drain(fd, 0.5, 8)  # startup and the pre-started shell settle
        done = []
        for _ in range(args.toggles):
            t0 = time.perf_counter()
            os.write(fd, b"\x1bt")  # Alt-t
            _, last = drain(fd, 0.05, 3)
            if last:
                done.append((last - t0) * 1000)
    finally:
        os.kill(pid, 9)
        os.unlink(init)

    if len(done) < args.toggles:
        print(f"only {len(done)}/{args.toggles} toggles produced a redraw", file=sys.stderr)
        return 2
    done.sort()
    median = statistics.median(done)
    p95 = done[int(len(done) * 0.95) - 1]
    print(f"toggles={len(done)} size={cols}x{rows} median={median:.2f}ms p95={p95:.2f}ms max={done[-1]:.2f}ms")
    if median > args.max_median_ms:
        print(f"median {median:.2f}ms is over the {args.max_median_ms}ms budget", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
