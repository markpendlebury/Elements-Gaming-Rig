import os
import argparse

def get_brightness():
    with open('/sys/class/backlight/amdgpu_bl1/brightness', 'r') as f:
        return int(f.read())

def set_brightness(brightness):
    with open('/sys/class/backlight/amdgpu_bl1/brightness', 'w') as f:
        f.write(str(brightness))

def main(direction):
    brightness = get_brightness()
    if brightness > 0:
        brightness -= 1
    set_brightness(brightness)



parser = argparse.ArgumentParser(action='store')