import math
import struct
import wave
import os

SAMPLE_RATE = 48000

def synth_pulse(freq, duration_s, amp=4500, attack_ms=2.0, release_ms=15.0, sub_harm=0.18, harm2=0.10, harm3=0.04):
    """
    Sintetizador de pulso digital con profundidad ('profundo' pero ágil):
    - 3% menos agudo (freq * 0.97)
    - Componente subarmónico (sub_harm) a freq/2 para cuerpo y profundidad
    """
    num_samples = int(SAMPLE_RATE * duration_s)
    samples = []
    attack_samples = max(1, int(SAMPLE_RATE * (attack_ms / 1000.0)))
    release_samples = max(1, int(SAMPLE_RATE * (release_ms / 1000.0)))
    sustain_samples = max(0, num_samples - attack_samples - release_samples)

    for i in range(num_samples):
        t = i / SAMPLE_RATE
        if i < attack_samples:
            frac = i / attack_samples
            env = 0.5 * (1.0 - math.cos(math.pi * frac))
        elif i < attack_samples + sustain_samples:
            env = 1.0
        else:
            rel_i = i - (attack_samples + sustain_samples)
            frac = rel_i / release_samples
            env = math.exp(-3.5 * frac) * (1.0 - frac)

        # Onda rica con profundidad
        wave_val = (
            math.sin(2.0 * math.pi * freq * t)
            + sub_harm * math.sin(1.0 * math.pi * freq * t) # sub-octava cálida para profundidad
            + harm2 * math.sin(4.0 * math.pi * freq * t)
            + harm3 * math.sin(6.0 * math.pi * freq * t)
        ) / (1.0 + sub_harm + harm2 + harm3)

        val = int(amp * env * wave_val)
        val = max(-32767, min(32767, val))
        samples.append(val)
    return samples

def synth_silence(duration_s):
    return [0] * int(SAMPLE_RATE * duration_s)

def synth_damped_click(start_freq, end_freq, duration_s, amp=4500, decay_rate=6.0, sub=0.25):
    """Click táctil de bloqueo/desbloqueo con cuerpo y amortiguación."""
    num_samples = int(SAMPLE_RATE * duration_s)
    samples = []
    phase = 0.0
    for i in range(num_samples):
        frac = i / num_samples
        freq = start_freq * math.pow(end_freq / start_freq, frac)
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        env = math.exp(-decay_rate * frac)
        val = int(amp * env * (math.sin(phase) + sub * math.sin(phase * 0.5)))
        val = max(-32767, min(32767, val))
        samples.append(val)
    return samples

def save_wav(path, samples):
    data = struct.pack(f"<{len(samples)}h", *samples)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(data)

# Test Lock: Latch táctil sólido tipo caja fuerte digital
lock_s = []
lock_s += synth_damped_click(2200.0 * 0.97, 1200.0 * 0.97, 0.015, amp=3800, decay_rate=8.0)
lock_s += synth_silence(0.012)
lock_s += synth_damped_click(650.0 * 0.97, 280.0 * 0.97, 0.040, amp=4500, decay_rate=5.0, sub=0.4)
save_wav("/tmp/test_lock.wav", lock_s)

# Test Unlock: Liberación táctil ascendente fluida
unlock_s = []
unlock_s += synth_damped_click(480.0 * 0.97, 850.0 * 0.97, 0.018, amp=3600, decay_rate=6.0, sub=0.3)
unlock_s += synth_silence(0.012)
unlock_s += synth_pulse(1850.0 * 0.97, 0.045, amp=4200, attack_ms=1.5, release_ms=18.0)
save_wav("/tmp/test_unlock.wav", unlock_s)

# Test Charge: Chime de carga de energía moderno, armónico y con cuerpo
charge_s = []
charge_s += synth_silence(0.020)
charge_s += synth_pulse(784.0 * 0.97, 0.055, amp=3600, attack_ms=2.0, release_ms=18.0, sub_harm=0.25)
charge_s += synth_silence(0.025)
charge_s += synth_pulse(1175.0 * 0.97, 0.060, amp=4000, attack_ms=2.0, release_ms=20.0, sub_harm=0.20)
charge_s += synth_silence(0.025)
charge_s += synth_pulse(1568.0 * 0.97, 0.160, amp=4400, attack_ms=2.0, release_ms=60.0, sub_harm=0.15)
charge_s += synth_silence(0.030)
save_wav("/tmp/test_charge.wav", charge_s)

# Test Settings Close: Micro-bit sutil descendente para cerrar Super + I
close_s = []
close_s += synth_silence(0.010)
close_s += synth_pulse(1568.0 * 0.97, 0.035, amp=3400, attack_ms=1.5, release_ms=12.0)
close_s += synth_silence(0.020)
close_s += synth_pulse(1046.5 * 0.97, 0.055, amp=3800, attack_ms=1.5, release_ms=22.0, sub_harm=0.2)
close_s += synth_silence(0.015)
save_wav("/tmp/test_settings_close.wav", close_s)

print("Test sounds created successfully!")
