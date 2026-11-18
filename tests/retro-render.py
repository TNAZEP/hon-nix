"""Manual Vulkan rendering check, using generated images and temporary app state.

Run inside a Wayland desktop: python tests/retro-render.py RETRO_PLAY OUTPUT_DIR
This opens short-lived preview windows. It never loads game content.
"""

import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import zlib


def png_chunk(kind, data):
    return (struct.pack("!I", len(data)) + kind + data
            + struct.pack("!I", zlib.crc32(kind + data)))


def pattern(path, width, height):
    colors = [(235, 235, 235), (235, 235, 0), (0, 235, 235), (0, 235, 0),
              (235, 0, 235), (235, 0, 0), (0, 0, 235), (16, 16, 16)]
    rows = b"".join(
        b"\0" + b"".join(
            bytes(colors[x * 8 // width]) if y < height * 3 // 4
            else bytes([((x // 8 + y // 8) % 2) * 255] * 3)
            for x in range(width)) for y in range(height))
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack("!IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(rows)) + png_chunk(b"IEND", b""))


launcher = Path(sys.argv[1]).resolve(strict=True)
output = Path(sys.argv[2]).resolve()
output.mkdir(parents=True, exist_ok=False)
results = {}
with tempfile.TemporaryDirectory(prefix="hon-retro-render-") as temporary:
    base = Path(temporary)
    for presentation, controller, width, height in (
        ("crt", "n64", 320, 240), ("gba-lcd", "ultimate2", 240, 160),
        ("raw", "ultimate2", 320, 240),
    ):
        print(f"Rendering {presentation}", flush=True)
        home = base / presentation
        config = home / "config/hon-retro/retroarch.cfg"
        config.parent.mkdir(parents=True)
        config.write_text(
            'video_driver = "vulkan"\nvideo_context_driver = "wayland"\n'
            'input_driver = "null"\naudio_enable = "false"\n'
            'microphone_enable = "false"\nvideo_font_enable = "false"\n'
            'video_fullscreen = "false"\nvideo_window_width = "960"\n'
            'video_window_height = "720"\nvideo_gpu_screenshot = "true"\n'
            'config_save_on_exit = "false"\nmenu_driver = "rgui"\n')
        original = config.read_bytes()
        image = output / f"{presentation}-input.png"
        pattern(image, width, height)
        env = os.environ | {
            "HOME": str(home), "XDG_CONFIG_HOME": str(home / "config"),
            "XDG_DATA_HOME": str(home / "data"), "SDL_JOYSTICK_HIDAPI_GAMECUBE": "0",
        }
        screenshot = output / f"{presentation}.png"
        log_path = output / f"{presentation}.log"
        with log_path.open("w") as log:
            result = subprocess.run([
                str(launcher), "--profile", controller, "--presentation", presentation,
                "--verbose", "-L", "imageviewer", str(image), "--max-frames", "120",
                "--max-frames-ss", "--max-frames-ss-path", str(screenshot),
            ], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        assert result.returncode == 0, f"{presentation} exited {result.returncode}: {log_path}"
        assert screenshot.stat().st_size > 1000, f"Missing screenshot: {screenshot}"
        assert config.read_bytes() == original, "Writable base configuration changed"
        log = log_path.read_text()
        assert "[Vulkan] Using GPU:" in log, "Vulkan renderer was not used"
        if presentation != "raw":
            assert "[Slang] Compiling shader:" in log, "Shader pipeline was not compiled"
        results[presentation] = {"exit_code": result.returncode, "screenshot": screenshot.name}
        print(f"Passed {presentation}", flush=True)
    assert (output / "crt.png").read_bytes() != (output / "raw.png").read_bytes()
(output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
