#!/usr/bin/env python3
"""Synthesize the project's original, deterministic ambience and foley cues."""

from __future__ import annotations

import argparse
import math
from pathlib import Path
import random
import struct
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050
TAU = math.tau


def periodic_tone(t: float, frequency: float, duration: float, phase: float = 0.0) -> float:
    cycles = max(1, round(frequency * duration))
    return math.sin(TAU * cycles * t / duration + phase)


def seamless(samples: list[float], fade: float = 0.2) -> list[float]:
    count = min(int(RATE * fade), len(samples) // 4)
    result = samples[:]
    for index in range(count):
        mix = index / max(1, count - 1)
        blended = samples[index] * mix + samples[-count + index] * (1.0 - mix)
        result[index] = blended
        result[-count + index] = blended
    return result


def city_ambience(duration: float = 8.0) -> list[float]:
    rng = random.Random(20261117)
    oscillators = [
        (85.0 + index * 47.0, rng.uniform(0.0005, 0.0014), rng.uniform(0.0, TAU))
        for index in range(22)
    ]
    result = []
    for index in range(int(RATE * duration)):
        t = index / RATE
        hum = 0.018 * periodic_tone(t, 55, duration) + 0.009 * periodic_tone(t, 82.5, duration, 0.7)
        air = sum(amplitude * periodic_tone(t, frequency, duration, phase) for frequency, amplitude, phase in oscillators)
        traffic = 0.0
        for start, length, pitch in [(1.0, 2.4, 130.0), (5.0, 2.0, 174.0)]:
            local = (t - start) / length
            if 0.0 <= local <= 1.0:
                envelope = math.sin(math.pi * local) ** 2
                traffic += envelope * 0.012 * periodic_tone(t, pitch + local * 25.0, duration)
        result.append((hum + air + traffic) * 0.8)
    return result


def hole_move(duration: float = 2.0) -> list[float]:
    rng = random.Random(20261118)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(int(RATE * duration))]
    result = []
    low = 0.0
    for index, sample in enumerate(noise):
        t = index / RATE
        low += 0.035 * (sample - low)
        pulse = 0.65 + 0.35 * periodic_tone(t, 2.0, duration)
        rumble = 0.055 * periodic_tone(t, 47, duration) + 0.025 * periodic_tone(t, 71, duration, 1.2)
        result.append((low * 0.65 * pulse + rumble) * 0.8)
    return seamless(result)


def water_ambience(duration: float = 6.0) -> list[float]:
    rng = random.Random(20261119)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(int(RATE * duration))]
    result = []
    low = 0.0
    for index, sample in enumerate(noise):
        t = index / RATE
        low += 0.09 * (sample - low)
        wash = 0.5 + 0.25 * periodic_tone(t, 0.5, duration) + 0.15 * periodic_tone(t, 0.833, duration, 0.8)
        ripple = 0.012 * periodic_tone(t, 337, duration) * periodic_tone(t, 0.667, duration)
        result.append((low * 0.12 * wash + ripple) * 0.75)
    return seamless(result, 0.35)


def devour_large(duration: float = 0.48) -> list[float]:
    rng = random.Random(20261120)
    result = []
    low = 0.0
    for index in range(int(RATE * duration)):
        t = index / RATE
        progress = t / duration
        phase = TAU * (145.0 * t - 95.0 * t * t)
        envelope = math.exp(-7.0 * progress) * min(1.0, t / 0.008)
        noise = rng.uniform(-1.0, 1.0)
        low += 0.12 * (noise - low)
        body = math.sin(phase) * 0.42 + math.sin(phase * 0.51) * 0.18
        result.append((body + low * 0.8) * envelope * 0.7)
    return result


def devour_fence(duration: float = 0.24) -> list[float]:
    rng = random.Random(20261121)
    result = []
    for index in range(int(RATE * duration)):
        t = index / RATE
        progress = t / duration
        envelope = math.exp(-15.0 * progress) * min(1.0, t / 0.003)
        clack = math.sin(TAU * 740.0 * t) * 0.24 + math.sin(TAU * 1180.0 * t) * 0.12
        noise = rng.uniform(-1.0, 1.0) * 0.22 * math.exp(-35.0 * progress)
        result.append((clack + noise) * envelope * 0.65)
    return result


GENERATORS = {
    "city_ambience": city_ambience,
    "hole_move": hole_move,
    "water_ambience": water_ambience,
    "devour_large": devour_large,
    "devour_fence": devour_fence,
}


def encode(name: str, samples: list[float], temporary: Path, output: Path) -> None:
    wav_path = temporary / f"{name}.wav"
    peak = max(1e-9, max(abs(sample) for sample in samples))
    gain = min(1.0, 0.72 / peak)
    pcm = b"".join(struct.pack("<h", round(max(-1.0, min(1.0, sample * gain)) * 32767)) for sample in samples)
    with wave.open(str(wav_path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm)
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "4", str(output)],
        check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--temporary", type=Path, default=ROOT / "artifacts" / "audio_generated")
    args = parser.parse_args()
    args.temporary.mkdir(parents=True, exist_ok=True)
    destination = ROOT / "assets" / "game" / "audio"
    for name, generator in GENERATORS.items():
        samples = generator()
        encode(name, samples, args.temporary, destination / f"{name}.ogg")
        print(f"{name}: {len(samples) / RATE:.2f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
