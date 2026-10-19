#!/usr/bin/env python3
"""
Motor y Generador Integral de Sonidos para Panacea Shell.
Permite sintetizar packs completos:
- nothing: estilo Nothing OS (digital, bit, glockenspiel minimal)
- material: estilo Material You (cálido, acústico, profundo, marimba/cristal)
- zen: estilo Calma Zen (madera orgánica, frecuencias bajas, ultra suave)
- cyber: estilo Cyberpunk / Sci-Fi (síntesis FM brillante, tonos futuristas)
- retro: estilo Arcade 8-bit (ondas de pulso chiptune puras)
- custom: totalmente personalizable (estilo, ataque, caída, graves, brillo, afinación, calidez, reverb, vibrato, filtro, ganancia).
"""

import math
import struct
import wave
import os
import sys
import argparse

_script_sounds = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sounds")
if "PANACEA_DIR" in os.environ:
    DEFAULT_SOUNDS_DIR = os.path.join(os.environ["PANACEA_DIR"], "sounds")
elif os.path.isdir(_script_sounds):
    DEFAULT_SOUNDS_DIR = _script_sounds
else:
    DEFAULT_SOUNDS_DIR = os.path.expanduser(f"{os.environ.get('XDG_CONFIG_HOME', '~/.config')}/panacea/sounds")

SAMPLE_RATE = 48000

# Frecuencias base estándar (misma tonalidad e intervalos en todos los packs)
NOTES = {
    "C5": 523.25, "E5": 659.25, "F5": 698.46, "G5": 783.99, "A5": 880.00,
    "C6": 1046.50, "D6": 1174.66, "E6": 1318.51, "G6": 1567.98, "A6": 1760.00, "B6": 1975.53,
    "C7": 2093.00, "E7": 2637.02, "G7": 3135.96
}

def make_silence(duration_ms, channels=2):
    return [0] * (channels * int(SAMPLE_RATE * (duration_ms / 1000.0)))

def apply_audio_dsp(samples, spatial=0.5, reverb=0.0, cutoff=1.0, warmth=0.0, gain=1.0, channels=2):
    """
    Procesador DSP de estudio:
    - warmth (0..1): distorsión armónica analógica y coloración cálida
    - cutoff (0.1..1.0): filtro pasa-bajos dinámico
    - reverb (0..1): cola acústica de sala y reflexiones difusas
    - spatial (0..1): apertura estéreo y difusión lateral
    - gain (0.4..2.0): ganancia maestra
    - channels: 1 para mono, 2 para estéreo entrelazado
    """
    if not samples:
        return samples
    n = len(samples)
    mono = [float(x) for x in samples]

    # 1. Calidez & Saturación Analógica
    if warmth > 0.01:
        for i in range(n):
            v = mono[i]
            # Armónico par cálido tipo válvula/tubo
            v = v + (warmth * 0.22 * (v * v) / 32768.0)
            mono[i] = math.tanh(v / 22000.0) * 21000.0

    # 2. Filtro Pasa-Bajos
    if cutoff < 0.98:
        cut_hz = max(350.0, min(20000.0, 400.0 + (math.pow(cutoff, 1.8)) * 19600.0))
        rc = 1.0 / (2.0 * math.pi * cut_hz)
        dt = 1.0 / SAMPLE_RATE
        alpha = dt / (rc + dt)
        lp = mono[0]
        for i in range(n):
            lp += alpha * (mono[i] - lp)
            mono[i] = lp

    # 3. Cola de Reverb Acústica (Independiente de la espacialidad estéreo)
    if reverb > 0.001:
        rev_tail_len = int(round(SAMPLE_RATE * 0.35 * reverb))
        mono.extend([0.0] * rev_tail_len)
        tot = len(mono)
        d1 = int(SAMPLE_RATE * 0.023)
        d2 = int(SAMPLE_RATE * 0.041)
        d3 = int(SAMPLE_RATE * 0.063)
        d4 = int(SAMPLE_RATE * 0.089)
        wet_gain = 0.38 * reverb
        for i in range(tot):
            r = 0.0
            if i >= d1: r += mono[i - d1] * (0.28 * wet_gain)
            if i >= d2: r += mono[i - d2] * (0.22 * wet_gain)
            if i >= d3: r += mono[i - d3] * (0.16 * wet_gain)
            if i >= d4: r += mono[i - d4] * (0.10 * wet_gain)
            mono[i] += r

    # 4. Apertura Estéreo / Difusión Espacial (Independiente de la cola de reverb)
    tot = len(mono)
    g = max(0.2, min(2.5, gain))

    if channels == 1 or spatial <= 0.001:
        final_samples = []
        for x in mono:
            val = int(max(-32767, min(32767, x * g)))
            if channels == 2:
                final_samples.extend([val, val])
            else:
                final_samples.append(val)
        return final_samples

    # Haas delay & Mid/Side spatial opening
    haas = max(1, int(SAMPLE_RATE * (0.00075 * spatial)))
    d_lat1 = int(SAMPLE_RATE * 0.012)
    d_lat2 = int(SAMPLE_RATE * 0.019)
    final_samples = []

    for i in range(tot):
        m = mono[i]
        m_haas = mono[i - haas] if i >= haas else m
        lat_diff = 0.0
        if i >= d_lat1: lat_diff += mono[i - d_lat1] * 0.15
        if i >= d_lat2: lat_diff -= mono[i - d_lat2] * 0.12

        mid = m
        side = ((m - m_haas) * 0.85 + lat_diff) * spatial

        left_val = int(max(-32767, min(32767, (mid + side) * g)))
        right_val = int(max(-32767, min(32767, (mid - side) * g)))
        final_samples.extend([left_val, right_val])

    return final_samples

def synth_tone(freq, duration_ms, style="marimba", depth=0.5, attack=0.5, decay=1.0, brightness=0.5,
               pitch=0.0, warmth=0.2, spatial=0.5, reverb=0.2, vibrato=0.0, cutoff=1.0, gain=1.0,
               amp=8000, channels=2):
    """
    Sintetizador universal multifuncional con parámetros físicos ampliados.
    """
    p_factor = math.pow(2.0, pitch / 12.0)
    base_freq = freq * p_factor

    total_samples = int(SAMPLE_RATE * (duration_ms * decay / 1000.0))
    att_ms = 0.8 + attack * 9.0  # 0.8ms a 9.8ms
    att_samples = max(1, int(SAMPLE_RATE * (att_ms / 1000.0)))
    tau_samples = SAMPLE_RATE * (0.050 * decay)

    samples = []
    fm_index = 1.8 if style == "fm" else (0.4 if style == "glass" else 0.0)

    for i in range(total_samples):
        t = i / SAMPLE_RATE

        # Envolvente
        if i < att_samples:
            env = 0.5 * (1.0 - math.cos(math.pi * (i / att_samples)))
        else:
            rel_i = i - att_samples
            env = math.exp(-rel_i / tau_samples)
            remaining = total_samples - i
            fade_samples = int(SAMPLE_RATE * 0.010)
            if remaining < fade_samples:
                env *= (remaining / fade_samples)

        # Frecuencia con vibrato opcional
        cur_freq = base_freq
        if vibrato > 0.01:
            cur_freq *= (1.0 + vibrato * 0.035 * math.sin(2.0 * math.pi * 5.5 * t))

        # Síntesis según estilo
        if style == "bit":
            p = (cur_freq * t) % 1.0
            wave_val = 1.0 if p < (0.35 + 0.15 * brightness) else -1.0
            if depth > 0.3:
                p_sub = (0.5 * cur_freq * t) % 1.0
                sub_val = 1.0 if p_sub < 0.5 else -1.0
                wave_val = 0.7 * wave_val + 0.3 * depth * sub_val
        elif style == "fm":
            mod_env = math.exp(-t * 40.0)
            modulator = math.sin(2.0 * math.pi * (cur_freq * 2.0) * t)
            wave_val = math.sin(2.0 * math.pi * cur_freq * t + fm_index * mod_env * modulator)
            if depth > 0:
                wave_val += depth * 0.5 * math.sin(1.0 * math.pi * cur_freq * t)
        elif style == "glass":
            f1 = math.sin(2.0 * math.pi * cur_freq * t)
            sub = depth * 0.6 * math.sin(1.0 * math.pi * cur_freq * t)
            h2 = (0.1 + brightness * 0.3) * math.sin(4.0 * math.pi * cur_freq * t) * math.exp(-t * 30.0)
            h3 = (0.05 + brightness * 0.2) * math.sin(6.0 * math.pi * cur_freq * t) * math.exp(-t * 50.0)
            wave_val = (f1 + sub + h2 + h3) / (1.0 + depth * 0.6 + 0.15 + 0.05)
        elif style == "bubble":
            f_inst = cur_freq * math.exp(-t * 12.0)
            wave_val = math.sin(2.0 * math.pi * f_inst * t)
            if depth > 0:
                wave_val += depth * 0.5 * math.sin(1.0 * math.pi * f_inst * 0.5 * t)
        else: # "marimba" (acústico orgánico)
            thump_env = math.exp(-t * 85.0)
            thump = (0.2 + depth * 0.25) * math.sin(2.0 * math.pi * 160.0 * t) * thump_env
            f1 = math.sin(2.0 * math.pi * cur_freq * t)
            sub = depth * 0.65 * math.sin(1.0 * math.pi * cur_freq * t)
            sub2 = (depth * 0.3 * math.sin(0.5 * math.pi * cur_freq * t)) if cur_freq > 800 else 0.0
            h2 = (0.05 + brightness * 0.25) * math.sin(4.0 * math.pi * cur_freq * t) * math.exp(-t * 35.0)
            wave_val = (f1 + sub + sub2 + h2 + thump) / (1.0 + depth * 0.95 + 0.15 + 0.25)

        raw = amp * env * wave_val
        sat = math.tanh(raw / 16000.0) * 15500.0
        samples.append(sat)

    return apply_audio_dsp(samples, spatial=spatial, reverb=reverb, cutoff=cutoff, warmth=warmth, gain=gain, channels=channels)

def synth_pop(start_freq, end_freq, duration_ms, depth=0.5, decay=1.0,
              pitch=0.0, warmth=0.2, spatial=0.5, reverb=0.2, cutoff=1.0, gain=1.0,
              amp=8000, channels=2):
    """Pop acústico táctil."""
    p_factor = math.pow(2.0, pitch / 12.0)
    sf = start_freq * p_factor
    ef = end_freq * p_factor

    total_samples = int(SAMPLE_RATE * (duration_ms * decay / 1000.0))
    tau_samples = SAMPLE_RATE * (0.035 * decay)
    att_samples = max(1, int(SAMPLE_RATE * 0.003))

    samples = []
    phase = 0.0
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        frac = i / total_samples

        f_inst = sf * math.pow(ef / sf, math.pow(frac, 0.60))
        phase += 2.0 * math.pi * f_inst / SAMPLE_RATE

        if i < att_samples:
            env = 0.5 * (1.0 - math.cos(math.pi * (i / att_samples)))
        else:
            rel_i = i - att_samples
            env = math.exp(-rel_i / tau_samples)

        sub_body = depth * 0.55 * math.sin(2.0 * math.pi * 150.0 * t) * math.exp(-t * 40.0)
        signal = (math.sin(phase) + sub_body) / (1.0 + depth * 0.55)
        raw = amp * env * signal
        sat = math.tanh(raw / 15000.0) * 14500.0
        samples.append(sat)

    return apply_audio_dsp(samples, spatial=spatial, reverb=reverb, cutoff=cutoff, warmth=warmth, gain=gain, channels=channels)

def save_wav(pack_dir, filename, samples, channels=2):
    os.makedirs(pack_dir, exist_ok=True)
    filepath = os.path.join(pack_dir, filename)
    data = struct.pack(f"<{len(samples)}h", *samples)
    with wave.open(filepath, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(data)

def generate_pack(pack_name, style="marimba", depth=0.5, attack=0.5, decay=1.0, brightness=0.5,
                  pitch=0.0, warmth=0.2, spatial=0.5, reverb=0.2, vibrato=0.0, cutoff=1.0, gain=1.0,
                  channels=2):
    """Genera la suite completa de 23 sonidos con los parámetros dados."""
    base_dir = pack_name if os.path.isabs(pack_name) else os.path.join(DEFAULT_SOUNDS_DIR, pack_name)
    os.makedirs(base_dir, exist_ok=True)
    kw = dict(style=style, depth=depth, attack=attack, decay=decay, brightness=brightness,
              pitch=pitch, warmth=warmth, spatial=spatial, reverb=reverb, vibrato=vibrato, cutoff=cutoff, gain=gain, channels=channels)
    pop_kw = dict(depth=depth, decay=decay, pitch=pitch, warmth=warmth, spatial=spatial, reverb=reverb, cutoff=cutoff, gain=gain, channels=channels)

    # 1. connect (C6 -> G6 -> C7)
    s = make_silence(20)
    s += synth_tone(NOTES["C6"], 85.0, **kw)
    s += make_silence(12)
    s += synth_tone(NOTES["G6"], 90.0, **kw)
    s += make_silence(12)
    s += synth_tone(NOTES["C7"], 160.0, **kw)
    s += make_silence(25)
    save_wav(base_dir, "connect.wav", s)

    # 2. disconnect (C7 -> G6 -> E6)
    s = make_silence(20)
    s += synth_tone(NOTES["C7"], 85.0, **kw)
    s += make_silence(12)
    s += synth_tone(NOTES["G6"], 90.0, **kw)
    s += make_silence(12)
    s += synth_tone(NOTES["E6"], 160.0, **kw)
    s += make_silence(25)
    save_wav(base_dir, "disconnect.wav", s)

    # 3. charge (G5 -> C6 -> G6)
    s = make_silence(15)
    s += synth_tone(NOTES["G5"], 85.0, **kw)
    s += make_silence(14)
    s += synth_tone(NOTES["C6"], 95.0, **kw)
    s += make_silence(14)
    s += synth_tone(NOTES["G6"], 220.0, **kw)
    s += make_silence(25)
    save_wav(base_dir, "charge.wav", s)

    # 4. mode_powersave (E5 -> C5)
    s = make_silence(15)
    s += synth_tone(NOTES["E5"], 110.0, **kw)
    s += make_silence(18)
    s += synth_tone(NOTES["C5"], 180.0, **kw)
    s += make_silence(20)
    save_wav(base_dir, "mode_powersave.wav", s)

    # 5. mode_balanced (G5 -> C6)
    s = make_silence(15)
    s += synth_tone(NOTES["G5"], 80.0, **kw)
    s += make_silence(16)
    s += synth_tone(NOTES["C6"], 140.0, **kw)
    s += make_silence(20)
    save_wav(base_dir, "mode_balanced.wav", s)

    # 6. mode_performance (C6 -> E6 -> G6)
    s = make_silence(15)
    s += synth_tone(NOTES["C6"], 65.0, **kw)
    s += make_silence(10)
    s += synth_tone(NOTES["E6"], 65.0, **kw)
    s += make_silence(10)
    s += synth_tone(NOTES["G6"], 160.0, **kw)
    s += make_silence(20)
    save_wav(base_dir, "mode_performance.wav", s)

    # 7. batt_full (C6 -> G6)
    s = make_silence(15)
    s += synth_tone(NOTES["C6"], 85.0, **kw)
    s += make_silence(14)
    s += synth_tone(NOTES["G6"], 190.0, **kw)
    s += make_silence(20)
    save_wav(base_dir, "batt_full.wav", s)

    # 8. lowbatt (G5 -> C5)
    s = make_silence(15)
    s += synth_tone(NOTES["G5"], 90.0, **kw)
    s += make_silence(20)
    s += synth_tone(NOTES["C5"], 210.0, **kw)
    s += make_silence(25)
    save_wav(base_dir, "lowbatt.wav", s)

    # 9. lock
    s = make_silence(5)
    s += synth_tone(NOTES["G5"], 70.0, **kw)
    s += make_silence(10)
    s += synth_tone(NOTES["C5"], 85.0, **kw)
    s += make_silence(10)
    save_wav(base_dir, "lock.wav", s)

    # 10. unlock
    s = make_silence(5)
    s += synth_tone(NOTES["C5"], 65.0, **kw)
    s += make_silence(10)
    s += synth_tone(NOTES["G5"], 95.0, **kw)
    s += make_silence(10)
    save_wav(base_dir, "unlock.wav", s)

    # 11. settings_open
    s = make_silence(5)
    s += synth_tone(NOTES["E6"], 45.0, **kw)
    s += make_silence(8)
    s += synth_tone(NOTES["A6"], 85.0, **kw)
    s += make_silence(10)
    save_wav(base_dir, "settings_open.wav", s)

    # 12. settings_close
    s = make_silence(5)
    s += synth_tone(NOTES["A6"], 40.0, **kw)
    s += make_silence(8)
    s += synth_tone(NOTES["E6"], 80.0, **kw)
    s += make_silence(10)
    save_wav(base_dir, "settings_close.wav", s)

    # 13. notification
    s = make_silence(10)
    s += synth_tone(NOTES["C6"], 70.0, **kw)
    s += make_silence(10)
    s += synth_tone(NOTES["E6"], 70.0, **kw)
    s += make_silence(10)
    s += synth_tone(NOTES["A6"], 140.0, **kw)
    s += make_silence(15)
    save_wav(base_dir, "notification.wav", s)

    # 14. screenshot
    s = make_silence(5)
    s += synth_tone(NOTES["E6"], 30.0, **kw)
    s += make_silence(6)
    s += synth_tone(NOTES["C7"], 70.0, **kw)
    s += make_silence(8)
    save_wav(base_dir, "screenshot.wav", s)

    # 15. voice_start
    s = make_silence(15)
    s += synth_tone(NOTES["C6"], 75.0, **kw)
    s += make_silence(14)
    s += synth_tone(NOTES["G6"], 140.0, **kw)
    s += make_silence(15)
    save_wav(base_dir, "voice_start.wav", s)

    # 16. voice_done
    s = make_silence(15)
    s += synth_tone(NOTES["G6"], 70.0, **kw)
    s += make_silence(12)
    s += synth_tone(NOTES["C6"], 150.0, **kw)
    s += make_silence(15)
    save_wav(base_dir, "voice_done.wav", s)

    # 17. island_pop
    s = make_silence(4)
    s += synth_pop(1150.0, 420.0, 75.0, **pop_kw)
    s += make_silence(6)
    save_wav(base_dir, "island_pop.wav", s)

    # 18. tock
    s = make_silence(2)
    s += synth_tone(NOTES["E6"], 38.0, **kw)
    s += make_silence(4)
    save_wav(base_dir, "tock.wav", s)

    # 19. kbd_light
    s0 = make_silence(4)
    s0 += synth_pop(680.0, 320.0, 65.0, **pop_kw)
    s0 += make_silence(5)
    save_wav(base_dir, "kbd_light_0.wav", s0)

    s1 = make_silence(5)
    s1 += synth_tone(NOTES["A5"], 100.0, **kw)
    s1 += make_silence(5)
    save_wav(base_dir, "kbd_light_1.wav", s1)

    s2 = make_silence(5)
    s2 += synth_tone(NOTES["A5"], 65.0, **kw)
    s2 += make_silence(12)
    s2 += synth_tone(NOTES["E6"], 120.0, **kw)
    s2 += make_silence(5)
    save_wav(base_dir, "kbd_light_2.wav", s2)
    save_wav(base_dir, "kbd_light.wav", s2)

    # 20. vol_tick
    s = make_silence(2)
    s += synth_tone(NOTES["D6"], 40.0, **kw)
    s += make_silence(2)
    save_wav(base_dir, "vol_tick.wav", s)

    print(f"Pack '{pack_name}' successfully generated in {base_dir}")

def main():
    parser = argparse.ArgumentParser(description="Sound Engine for Panacea Shell")
    parser.add_argument("action", choices=["preset", "generate", "list", "preview"], help="Accion a realizar")
    parser.add_argument("--pack", default="custom", help="Nombre del pack destino")
    parser.add_argument("--style", default="marimba", choices=["marimba", "glass", "fm", "bit", "bubble"])
    parser.add_argument("--depth", type=float, default=0.5, help="Profundidad de graves (0.0 a 1.0)")
    parser.add_argument("--attack", type=float, default=0.5, help="Suavidad de ataque (0.0 a 1.0)")
    parser.add_argument("--decay", type=float, default=1.0, help="Multiplicador de caida/sosten (0.4 a 2.5)")
    parser.add_argument("--brightness", type=float, default=0.5, help="Brillo de armonicos altos (0.0 a 1.0)")
    parser.add_argument("--pitch", type=float, default=0.0, help="Afinacion / semitonos (-12.0 a +12.0)")
    parser.add_argument("--warmth", type=float, default=0.2, help="Saturacion analogica y calidez (0.0 a 1.0)")
    parser.add_argument("--spatial", "--spatial-width", dest="spatial", type=float, default=0.5, help="Espacialidad estéreo / apertura lateral (0.0 a 1.0)")
    parser.add_argument("--reverb", type=float, default=0.2, help="Cola de reverberación y reflexiones de sala (0.0 a 1.0)")
    parser.add_argument("--vibrato", type=float, default=0.0, help="Modulacion / vibrato (0.0 a 1.0)")
    parser.add_argument("--cutoff", type=float, default=1.0, help="Filtro pasa-bajos (0.2 a 1.0)")
    parser.add_argument("--gain", type=float, default=1.0, help="Ganancia maestra (0.5 a 1.5)")
    args = parser.parse_args()

    if args.action == "list":
        sounds_dir = DEFAULT_SOUNDS_DIR
        packs = [d for d in os.listdir(sounds_dir) if os.path.isdir(os.path.join(sounds_dir, d))]
        print(",".join(packs))
        return

    kw = {
        "style": args.style,
        "depth": args.depth,
        "attack": args.attack,
        "decay": args.decay,
        "brightness": args.brightness,
        "pitch": args.pitch,
        "warmth": args.warmth,
        "spatial": args.spatial,
        "reverb": args.reverb,
        "vibrato": args.vibrato,
        "cutoff": args.cutoff,
        "gain": args.gain,
        "channels": 2
    }

    if args.action == "preview":
        s = make_silence(10, channels=2)
        s += synth_tone(NOTES["C6"], 60.0, **kw)
        s += make_silence(8, channels=2)
        s += synth_tone(NOTES["E6"], 60.0, **kw)
        s += make_silence(8, channels=2)
        s += synth_tone(NOTES["G6"], 140.0, **kw)
        s += make_silence(25, channels=2)
        tmp_path = "/tmp/panacea_sound_preview.wav"
        save_wav("/tmp", "panacea_sound_preview.wav", s, channels=2)
        os.system(f"pkill -f 'panacea_sound_preview.wav' 2>/dev/null || true; pw-play '{tmp_path}' 2>/dev/null || paplay '{tmp_path}' 2>/dev/null &")
        print(f"Preview generated and played: {tmp_path}")
        return

    if args.action == "preset":
        if args.pack == "material":
            generate_pack("material", style="marimba", depth=0.60, attack=0.60, decay=1.1, brightness=0.45, warmth=0.35, spatial=0.60, reverb=0.20, channels=2)
        elif args.pack == "zen":
            generate_pack("zen", style="marimba", depth=0.85, attack=0.85, decay=1.35, brightness=0.25, pitch=-2.0, warmth=0.50, spatial=0.40, reverb=0.35, channels=2)
        elif args.pack == "cyber":
            generate_pack("cyber", style="fm", depth=0.40, attack=0.30, decay=0.90, brightness=0.80, vibrato=0.25, spatial=0.75, reverb=0.10, channels=2)
        elif args.pack == "retro":
            generate_pack("retro", style="bit", depth=0.20, attack=0.05, decay=0.75, brightness=0.60, warmth=0.0, spatial=0.0, reverb=0.0, channels=2)
        elif args.pack == "bubble":
            generate_pack("bubble", style="bubble", depth=0.75, attack=0.60, decay=1.0, brightness=0.35, warmth=0.25, spatial=0.50, reverb=0.25, channels=2)
        elif args.pack == "custom":
            generate_pack("custom", **kw)
    elif args.action == "generate":
        generate_pack(args.pack, **kw)

if __name__ == "__main__":
    main()
