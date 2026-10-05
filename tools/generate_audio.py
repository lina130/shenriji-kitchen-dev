from array import array
from pathlib import Path
import math
import random
import wave

ROOT = Path(r"C:\Users\18257\Desktop\深日记\assets\audio")
RATE = 22050
random.seed(20260926)


def write_wav(name: str, samples: list[float]) -> None:
    path = ROOT / f"{name}.wav"
    data = array("h")
    for sample in samples:
        value = max(-1.0, min(1.0, sample))
        data.append(int(value * 32767))
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(data.tobytes())


def envelope(index: int, total: int, attack: float = 0.04, release: float = 0.12) -> float:
    t = index / total
    if t < attack:
        return t / attack
    if t > 1.0 - release:
        return max(0.0, (1.0 - t) / release)
    return 1.0


def ambient(name: str, duration: float, notes: list[float], noise_level: float, brightness: float) -> None:
    total = int(duration * RATE)
    samples: list[float] = []
    for i in range(total):
        t = i / RATE
        value = 0.0
        for note_index, frequency in enumerate(notes):
            beat = 0.5 + 0.5 * math.sin(t * (0.10 + note_index * 0.017) + note_index * 1.7)
            value += math.sin(2 * math.pi * frequency * t) * (0.018 + beat * 0.018)
            value += math.sin(2 * math.pi * frequency * 2.0 * t) * 0.005 * brightness
        value += (random.random() * 2.0 - 1.0) * noise_level
        fade = min(1.0, t / 1.5, (duration - t) / 1.5)
        samples.append(value * max(0.0, fade))
    write_wav(name, samples)


def rain(duration: float = 24.0) -> None:
    total = int(duration * RATE)
    samples: list[float] = []
    low = 0.0
    for i in range(total):
        t = i / RATE
        raw = random.random() * 2.0 - 1.0
        low = low * 0.995 + raw * 0.005
        drop = 0.0
        if random.random() < 0.0007:
            drop = math.sin(2 * math.pi * random.uniform(700, 1300) * t) * 0.12
        samples.append((raw * 0.018 + low * 0.09 + drop) * min(1.0, t / 2.0, (duration - t) / 2.0))
    write_wav("rain_ambient", samples)


def effect(name: str, duration: float, frequencies: list[float], volume: float = 0.24) -> None:
    total = int(duration * RATE)
    samples: list[float] = []
    for i in range(total):
        t = i / RATE
        value = 0.0
        for index, frequency in enumerate(frequencies):
            value += math.sin(2 * math.pi * frequency * (1.0 + t * 0.08) * t) * (1.0 / (index + 1))
        samples.append(value * volume * envelope(i, total, 0.02, 0.3))
    write_wav(name, samples)


ambient("menu_ambient", 24.0, [110.0, 164.81, 220.0, 329.63], 0.004, 0.55)
ambient("day_ambient", 24.0, [196.0, 246.94, 293.66, 392.0], 0.003, 0.7)
ambient("night_ambient", 24.0, [82.41, 110.0, 146.83, 196.0], 0.003, 0.32)
rain(24.0)
effect("pickup", 0.28, [660.0, 990.0])
effect("legendary_pickup", 0.85, [523.25, 659.25, 783.99, 1046.5], 0.20)
effect("soft_confirm", 0.18, [440.0, 660.0], 0.16)
effect("soft_warning", 0.24, [220.0, 277.18], 0.15)
print("AUDIO_GENERATED")