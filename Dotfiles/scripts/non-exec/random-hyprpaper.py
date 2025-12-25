#!/usr/bin/env python3
import os
import subprocess
import random
import json
from pathlib import Path


def get_wallpapers():
    wallpaper_dir = Path.home() / "Pictures" / "Wallpapers"
    if not wallpaper_dir.exists():
        raise FileNotFoundError(f"Wallpaper directory not found: {wallpaper_dir}")

    extensions = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
    wallpapers = [
        f
        for f in wallpaper_dir.iterdir()
        if f.is_file() and f.suffix.lower() in extensions
    ]

    if not wallpapers:
        raise FileNotFoundError(f"No wallpapers found in {wallpaper_dir}")

    return wallpapers


def get_monitors():
    try:
        result = subprocess.run(
            ["hyprctl", "monitors", "-j"], capture_output=True, text=True, check=True
        )
        monitors = json.loads(result.stdout)
        return [monitor["name"] for monitor in monitors]
    except (subprocess.CalledProcessError, json.JSONDecodeError, KeyError):
        raise RuntimeError("Failed to get monitor information")


def main():
    try:
        wallpapers = get_wallpapers()
        monitors = get_monitors()

        if not monitors:
            raise RuntimeError("No monitors found")

        config_file = Path.home() / ".config" / "hypr" / "hyprpaper.conf"
        config_file.parent.mkdir(parents=True, exist_ok=True)

        selected_wallpapers = set()
        monitor_configs = []

        for monitor in monitors:
            wallpaper = random.choice(wallpapers)
            selected_wallpapers.add(wallpaper)
            monitor_configs.append(f"wallpaper = {monitor},{wallpaper}")

        with open(config_file, "w") as f:
            f.write("splash = false\n\n")
            for wallpaper in selected_wallpapers:
                f.write(f"preload = {wallpaper}\n")
            f.write("\n")
            for config in monitor_configs:
                f.write(f"{config}\n")

        subprocess.run(["pkill", "hyprpaper"], check=False)
        subprocess.run(["hyprpaper"], check=True)

    except Exception as e:
        print(f"Error: {e}")
        exit(1)


if __name__ == "__main__":
    main()
