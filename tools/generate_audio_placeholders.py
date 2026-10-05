from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"
FORMAL_AUDIO = AUDIO / "formal"
RATE = 22050
TAU = math.tau

TRACK_ROOTS = {
    "menu_ambient": 196.0,
    "day_ambient": 196.0,
    "night_ambient": 146.83,
    "home_ambient": 174.61,
    "street_ambient": 164.81,
    "commercial_ambient": 185.0,
    "high_end_ambient": 220.0,
    "industrial_ambient": 110.0,
    "workshop_ambient": 130.81,
    "farm_ambient": 146.83,
    "riverside_ambient": 174.61,
    "park_ambient": 196.0,
    "market_ambient": 185.0,
    "kitchen_ambient": 164.81,
    "breakfast_ambient": 196.0,
    "restaurant_ambient": 174.61,
    "night_market_ambient": 130.81,
    "livestock_ambient": 123.47,
    "store_ambient": 207.65,
    "clinic_ambient": 220.0,
    "university_ambient": 174.61,
    "travel_ambient": 155.56,
    "festival_ambient": 261.63,
    "ruins_ambient": 98.0,
}

def write_wav(name, samples, rate=RATE, directory=AUDIO):
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"{name}.wav"
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        frames = bytearray()
        for sample in samples:
            value = max(-1.0, min(1.0, sample))
            frames.extend(struct.pack("<h", int(value * 32767)))
        wav.writeframes(bytes(frames))

def make_track(name, duration=8.0):
    rng = random.Random(sum(ord(c) for c in name) + 20260927)
    root = TRACK_ROOTS.get(name, 174.61)
    intervals = [1.0, 1.1892, 1.3348, 1.4983, 1.6818, 1.7818]
    chord = [root * intervals[0], root * intervals[2], root * intervals[4]]
    high = root * 2.0
    noise = 0.0
    count = int(RATE * duration)
    result = []
    for i in range(count):
        t = i / RATE
        fade = min(1.0, t / 0.35, max(0.0, (duration - t) / 0.35))
        pulse = 0.58 + 0.42 * math.sin(TAU * 0.08 * t + rng.random() * 0.0)
        value = 0.0
        for index, frequency in enumerate(chord):
            value += math.sin(TAU * frequency * t + index * 0.8) * (0.080 / (index + 1))
        value += math.sin(TAU * high * t) * 0.018 * (0.65 + 0.35 * math.sin(TAU * 0.17 * t))
        if "industrial" in name or "workshop" in name or "kitchen" in name or "market" in name:
            noise = noise * 0.94 + rng.uniform(-1.0, 1.0) * 0.06
            value += noise * 0.10
        if "night" in name or "ruins" in name:
            value += math.sin(TAU * root * 0.5 * t) * 0.035
        if "festival" in name:
            value += math.sin(TAU * root * 1.5 * t) * 0.025
        result.append(value * pulse * fade)
    return result

def make_formal_track(name, duration=10.0):
    rng = random.Random(sum(ord(c) for c in "formal:" + name) + 20260927)
    root = TRACK_ROOTS.get(name, 174.61)
    intervals = [1.0, 1.1892, 1.3348, 1.4983, 1.6818, 1.7818, 2.0]
    chord = [root * intervals[0], root * intervals[2], root * intervals[4], root * intervals[5]]
    shimmer = root * 3.0
    noise = 0.0
    count = int(RATE * duration)
    result = []
    for i in range(count):
        t = i / RATE
        fade = min(1.0, t / 0.45, max(0.0, (duration - t) / 0.45))
        value = 0.0
        for index, frequency in enumerate(chord):
            phase = index * 1.1 + 0.25 * math.sin(TAU * (0.035 + index * 0.006) * t)
            value += math.sin(TAU * frequency * t + phase) * (0.062 / (index + 1))
        value += math.sin(TAU * shimmer * t) * 0.010 * (0.6 + 0.4 * math.sin(TAU * 0.11 * t))
        if any(word in name for word in ("industrial", "workshop", "kitchen", "market", "street", "logistics")):
            noise = noise * 0.955 + rng.uniform(-1.0, 1.0) * 0.045
            value += noise * 0.085
        if any(word in name for word in ("farm", "riverside", "park", "suburb")):
            value += math.sin(TAU * root * 3.7 * t) * 0.008 * max(0.0, math.sin(TAU * 0.19 * t))
        if any(word in name for word in ("night", "ruins", "festival")):
            value += math.sin(TAU * root * 0.5 * t) * 0.028
        result.append(value * fade)
    return result

def make_formal_rain(duration=10.0):
    rng = random.Random(20260928)
    count = int(RATE * duration)
    result = []
    soft = 0.0
    for i in range(count):
        t = i / RATE
        soft = soft * 0.94 + rng.uniform(-1.0, 1.0) * 0.06
        rain = soft * 0.26
        rain += math.sin(TAU * 180.0 * t) * 0.012 * rng.random()
        fade = min(1.0, t / 0.35, max(0.0, (duration - t) / 0.35))
        result.append(rain * fade)
    return result

def formal_tone(base, duration=0.28):
    count = int(RATE * duration)
    result = []
    for i in range(count):
        t = i / RATE
        envelope = min(1.0, t * 30.0) * max(0.0, 1.0 - t / duration)
        value = math.sin(TAU * base * t) * 0.20
        value += math.sin(TAU * base * 1.5 * t) * 0.08
        value += math.sin(TAU * base * 2.0 * t) * 0.035
        result.append(value * envelope)
    return result

def rain_ambient(duration=8.0):
    rng = random.Random(20260927)
    count = int(RATE * duration)
    result = []
    smoothed = 0.0
    for i in range(count):
        smoothed = smoothed * 0.93 + rng.uniform(-1.0, 1.0) * 0.07
        t = i / RATE
        fade = min(1.0, t / 0.25, max(0.0, (duration - t) / 0.25))
        result.append(smoothed * 0.34 * fade)
    return result

def pickup():
    duration = 0.18
    count = int(RATE * duration)
    result = []
    for i in range(count):
        t = i / RATE
        frequency = 720 + 560 * (t / duration)
        envelope = min(1.0, t * 35.0) * max(0.0, 1.0 - t / duration)
        result.append(math.sin(TAU * frequency * t) * envelope * 0.34)
    return result

def legendary_pickup():
    notes = [523.25, 659.25, 783.99, 1046.5]
    step = 0.18
    duration = len(notes) * step
    count = int(RATE * duration)
    result = []
    for i in range(count):
        t = i / RATE
        index = min(len(notes) - 1, int(t / step))
        local = t - index * step
        envelope = min(1.0, local * 30.0) * max(0.0, 1.0 - local / step)
        value = math.sin(TAU * notes[index] * t) * envelope * 0.30
        value += math.sin(TAU * notes[index] * 2.0 * t) * envelope * 0.08
        result.append(value)
    return result

def soft_confirm():
    duration = 0.24
    count = int(RATE * duration)
    result = []
    for i in range(count):
        t = i / RATE
        frequency = 520 if t < duration * 0.55 else 660
        envelope = min(1.0, t * 24.0) * max(0.0, 1.0 - t / duration)
        result.append(math.sin(TAU * frequency * t) * envelope * 0.25)
    return result

def soft_warning():
    duration = 0.36
    count = int(RATE * duration)
    result = []
    for i in range(count):
        t = i / RATE
        frequency = 260 - 90 * (t / duration)
        envelope = min(1.0, t * 18.0) * max(0.0, 1.0 - t / duration)
        result.append(math.sin(TAU * frequency * t) * envelope * 0.28)
    return result

def short_tone(name, base, duration=0.22):
    count = int(RATE * duration)
    result = []
    for i in range(count):
        t = i / RATE
        frequency = base * (1.0 + 0.18 * math.sin(TAU * 3.5 * t))
        envelope = min(1.0, t * 30.0) * max(0.0, 1.0 - t / duration)
        result.append(math.sin(TAU * frequency * t) * envelope * 0.22)
    return result

def main():
    for name in TRACK_ROOTS:
        write_wav(name, make_track(name))
    write_wav("rain_ambient", rain_ambient())
    write_wav("pickup", pickup())
    write_wav("legendary_pickup", legendary_pickup())
    write_wav("soft_confirm", soft_confirm())
    write_wav("soft_warning", soft_warning())
    for name in TRACK_ROOTS:
        write_wav(name, make_formal_track(name), directory=FORMAL_AUDIO)
    write_wav("rain_ambient", make_formal_rain(), directory=FORMAL_AUDIO)
    for name, base, duration in [("pickup", 700.0, 0.20), ("legendary_pickup", 880.0, 0.36), ("soft_confirm", 540.0, 0.25), ("soft_warning", 260.0, 0.34), ("door_open", 220.0, 0.34), ("coin", 660.0, 0.22), ("serve_bell", 880.0, 0.30), ("ui_open", 480.0, 0.18), ("ui_close", 360.0, 0.18)]:
        write_wav(name, formal_tone(base, duration), directory=FORMAL_AUDIO)
    write_wav("door_open", short_tone("door_open", 220.0, 0.32))
    write_wav("coin", short_tone("coin", 660.0, 0.20))
    write_wav("serve_bell", short_tone("serve_bell", 880.0, 0.28))
    write_wav("ui_open", short_tone("ui_open", 480.0, 0.16))
    write_wav("ui_close", short_tone("ui_close", 360.0, 0.16))
    print(f"audio placeholders generated under {AUDIO}")

if __name__ == "__main__":
    main()
