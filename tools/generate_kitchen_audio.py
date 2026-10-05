"""Create the original, deterministic kitchen score and tactile sound effects.

Run only this script when changing kitchen audio; the older placeholder generator
rewrites unrelated game sounds. All samples are synthesized locally, with no
downloaded music or external sound library.
"""

from pathlib import Path
import math
import wave

import numpy as np


RATE = 24000
TAU = math.tau
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "formal"
RNG = np.random.default_rng(20260928)


def save(name: str, samples: np.ndarray) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    samples = np.nan_to_num(samples)
    peak = float(np.max(np.abs(samples)))
    if peak > 0.88:
        samples = samples * (0.88 / peak)
    pcm = (np.clip(samples, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(pcm.tobytes())


def midi(note: int) -> float:
    return 440.0 * 2 ** ((note - 69) / 12)


def add_loop(buffer: np.ndarray, at: float, sound: np.ndarray) -> None:
    """Wrap note tails across the seam so the loop has no fade or gap."""
    offset = int(round(at * RATE)) % len(buffer)
    sound = sound[: len(buffer)]
    end = min(len(buffer) - offset, len(sound))
    buffer[offset : offset + end] += sound[:end]
    if end < len(sound):
        buffer[: len(sound) - end] += sound[end:]


def note(frequency: float, seconds: float, voice: str) -> np.ndarray:
    t = np.arange(int(RATE * seconds), dtype=np.float64) / RATE
    if voice == "felt":
        tone = (np.sin(TAU * frequency * t) + 0.17 * np.sin(TAU * frequency * 2 * t)
                + 0.045 * np.sin(TAU * frequency * 3 * t))
        envelope = (1 - np.exp(-t * 70)) * np.exp(-t * 5.0)
    elif voice == "wood":
        tone = (np.sin(TAU * frequency * t) + 0.28 * np.sin(TAU * frequency * 2.01 * t)
                + 0.12 * np.sin(TAU * frequency * 3.98 * t))
        envelope = (1 - np.exp(-t * 130)) * np.exp(-t * 10)
    elif voice == "bass":
        tone = np.sin(TAU * frequency * t) + 0.15 * np.sin(TAU * frequency * 2 * t)
        envelope = (1 - np.exp(-t * 45)) * np.exp(-t * 3.8)
    else:  # a quiet, breathing pad under the kitchen rhythm
        tone = (np.sin(TAU * frequency * t) + 0.21 * np.sin(TAU * frequency * 1.005 * t)
                + 0.08 * np.sin(TAU * frequency * 2 * t))
        envelope = np.minimum(1, t * 4) * np.minimum(1, (seconds - t) * 3)
    return tone * np.maximum(0, envelope)


def brush(seconds: float, brightness: float = 1.0) -> np.ndarray:
    t = np.arange(int(RATE * seconds), dtype=np.float64) / RATE
    raw = RNG.normal(0, 1, len(t))
    high = raw - np.convolve(raw, np.ones(15) / 15, mode="same")
    return high * np.exp(-t * 22) * brightness


def score(name: str, bpm: int, chords: list[list[int]], melody: list[list[int]],
          energy: float) -> None:
    beat = 60.0 / bpm
    bar = beat * 4
    length = bar * 8
    audio = np.zeros(int(round(length * RATE)), dtype=np.float64)
    for bar_index in range(8):
        chord = chords[bar_index % 4]
        phrase = melody[bar_index % 4]
        start = bar_index * bar
        for pitch in chord:
            add_loop(audio, start, note(midi(pitch), bar * 1.1, "pad") * (0.012 * energy))
        for beat_index in range(4):
            at = start + beat_index * beat
            add_loop(audio, at, note(midi(chord[0] - 12), beat * 0.95, "bass") * (0.105 * energy))
            add_loop(audio, at + beat * 0.5,
                     note(midi(chord[1] + 12), beat * 0.72, "wood") * (0.027 * energy))
            # Four short felt mallet notes form a recognisable melody. The second
            # phrase answers the first instead of restarting the same four bars.
            melodic_pitch = phrase[beat_index] + (12 if bar_index == 7 and beat_index == 3 else 0)
            add_loop(audio, at + (beat * 0.5 if beat_index == 1 else 0),
                     note(midi(melodic_pitch), beat * 1.45, "felt") * (0.10 * energy))
            if name == "kitchen_lunch" or beat_index in (0, 2):
                add_loop(audio, at, brush(0.14, 0.028 * energy))
            if beat_index in (1, 3):
                add_loop(audio, at, brush(0.10, 0.039 * energy))
            if name == "kitchen_lunch":
                add_loop(audio, at + beat * 0.75, brush(0.055, 0.018 * energy))
    # A tiny peak limiter leaves headroom for multiple simultaneous kitchen cues.
    audio = np.tanh(audio * 1.55) * 0.76
    save(name, audio)


def noise_hit(duration: float, decay: float, colour: str = "high") -> np.ndarray:
    t = np.arange(int(RATE * duration)) / RATE
    raw = RNG.normal(0, 1, len(t))
    if colour == "low":
        raw = np.convolve(raw, np.ones(28) / 28, mode="same")
    elif colour == "high":
        raw = raw - np.convolve(raw, np.ones(12) / 12, mode="same")
    return raw * np.exp(-t * decay) * (1 - np.exp(-t * 160))


def cue(name: str, duration: float, events: list[tuple[float, np.ndarray, float]]) -> None:
    audio = np.zeros(int(RATE * duration), dtype=np.float64)
    for at, sound, volume in events:
        offset = int(RATE * at)
        size = min(len(sound), len(audio) - offset)
        if size > 0:
            audio[offset : offset + size] += sound[:size] * volume
    audio = np.tanh(audio * 1.7) * 0.7
    save(name, audio)


def main() -> None:
    score("kitchen_morning", 98,
          [[60, 64, 67], [65, 69, 72], [57, 60, 64], [55, 59, 62]],
          [[67, 69, 72, 69], [69, 72, 74, 72], [72, 76, 79, 76], [71, 74, 76, 74]], 0.86)
    score("kitchen_lunch", 114,
          [[60, 64, 67], [65, 69, 72], [57, 60, 64], [55, 59, 62]],
          [[72, 76, 74, 67], [72, 74, 77, 76], [76, 79, 76, 72], [74, 79, 76, 71]], 1.0)
    score("kitchen_evening", 86,
          [[57, 60, 64], [65, 69, 72], [60, 64, 67], [55, 59, 62]],
          [[69, 72, 76, 72], [69, 72, 77, 76], [72, 76, 79, 76], [71, 74, 76, 71]], 0.76)

    felt = lambda pitch, time: note(midi(pitch), time, "felt")
    wood = lambda pitch, time: note(midi(pitch), time, "wood")
    bass = lambda pitch, time: note(midi(pitch), time, "bass")
    cue("kitchen_ticket", 0.30, [(0, noise_hit(.16, 26), .25), (.065, wood(75, .18), .25)])
    cue("kitchen_pantry", 0.34, [(0, noise_hit(.25, 17, "low"), .40), (.10, wood(52, .17), .34)])
    cue("kitchen_place", 0.27, [(0, wood(81, .22), .36), (.036, wood(76, .19), .20)])
    cue("kitchen_wash", 0.61, [(0, noise_hit(.40, 4), .25), (.07, felt(87, .13), .17),
                                (.22, felt(91, .16), .15)])
    cue("kitchen_slice", 0.34, [(0, noise_hit(.13, 35), .41), (.10, noise_hit(.13, 35), .34),
                                 (.19, wood(54, .13), .21)])
    cue("kitchen_mix", 0.64, [(0, noise_hit(.30, 7), .16), (.21, noise_hit(.30, 7), .16),
                               (.10, wood(69, .18), .18), (.36, wood(71, .18), .16)])
    cue("kitchen_marinate", 0.42, [(0, noise_hit(.21, 17, "low"), .40),
                                    (.12, wood(58, .22), .23)])
    cue("kitchen_portion", 0.34, [(0, wood(77, .28), .41), (.075, felt(84, .23), .19)])
    cue("kitchen_steam", 0.72, [(0, noise_hit(.67, 3.4), .22), (.05, bass(45, .30), .16)])
    cue("kitchen_fry", 0.80, [(0, noise_hit(.75, 2.9), .24),
                               (.13, noise_hit(.12, 25), .24), (.36, noise_hit(.13, 25), .19)])
    cue("kitchen_boil", 0.77, [(0, noise_hit(.60, 5, "low"), .26),
                                (.13, bass(50, .25), .18), (.38, bass(55, .22), .14)])
    cue("kitchen_garnish", 0.52, [(0, felt(84, .38), .36), (.10, felt(88, .38), .31),
                                   (.20, felt(91, .30), .28)])
    cue("kitchen_ready", 0.79, [(0, felt(79, .62), .40), (.20, felt(86, .54), .42)])
    cue("kitchen_serve", 0.67, [(0, wood(92, .48), .50), (.09, felt(80, .52), .24)])
    cue("kitchen_register", 1.02, [(0, noise_hit(.20, 20, "low"), .35),
                                    (.15, wood(86, .41), .30), (.23, felt(91, .51), .36),
                                    (.31, felt(96, .56), .30), (.59, noise_hit(.17, 18, "low"), .23)])
    cue("kitchen_warning", 0.51, [(0, wood(57, .35), .31), (.15, felt(55, .29), .22)])
    cue("kitchen_rush", 0.72, [(0, felt(79, .40), .39), (.16, felt(84, .40), .42),
                                (.33, felt(88, .36), .35)])
    print("KITCHEN_AUDIO_GENERATED", OUT)


if __name__ == "__main__":
    main()
