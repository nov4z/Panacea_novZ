#!/usr/bin/env python3
"""
Generador Acústico de Sonidos Material You (Material 3) para Panacea Shell.
Basado en los mismos tonos, intervalos y melodías del pack Nothing, pero con:
- Mayor profundidad ("más profundos"): subarmónicos a freq/2 y freq/4 para cuerpo acústico.
- Cero carácter 'bit' / chiptune: ataques suaves redondeados (3-6ms), sin recortes abruptos.
- Decaimiento exponencial orgánico (marimba cálida, láminas de cristal, Rhodes moderno).
- Transientes táctiles fluidos (thump acústico suave y saturación analógica).
"""

import math
import struct
import wave
import os

SAMPLE_RATE = 48000
PITCH_SCALE = 1.0  # Misma afinación natural que el diseño sonoro Nothing

def P(f):
    return f * PITCH_SCALE

def make_silence(duration_ms):
    return [0] * int(SAMPLE_RATE * (duration_ms / 1000.0))

def make_material_tone(freq, duration_ms, amp=8500, attack_ms=5.0, decay_tau_ms=70.0,
                       sub_weight=0.55, sub2_weight=0.20, harm2_weight=0.16, harm3_weight=0.05,
                       thump_freq=150.0, thump_weight=0.25):
    """
    Tono acústico orgánico Material You:
    - Fundamental puro
    - Subarmónico a freq/2 para profundidad real y graves cálidos
    - Subgrave a freq/4 para notas agudas (da base sólida a notas como C6, G6, C7)
    - Decaimiento progresivo natural (los armónicos altos caen rápido, el cuerpo perdura)
    - Envolvente de decaimiento suave y redondeada
    """
    total_samples = int(SAMPLE_RATE * (duration_ms / 1000.0))
    att_samples = max(1, int(SAMPLE_RATE * (attack_ms / 1000.0)))
    decay_tau_samples = SAMPLE_RATE * (decay_tau_ms / 1000.0)

    samples = []
    for i in range(total_samples):
        t = i / SAMPLE_RATE

        if i < att_samples:
            env = 0.5 * (1.0 - math.cos(math.pi * (i / att_samples)))
        else:
            rel_i = i - att_samples
            env = math.exp(-rel_i / decay_tau_samples)
            remaining = total_samples - i
            fade_samples = int(SAMPLE_RATE * 0.012)
            if remaining < fade_samples:
                env *= (remaining / fade_samples)

        # Transiente de golpe acústico amortiguado rápido en los primeros 12ms
        thump_env = math.exp(-t * 90.0)
        thump = thump_weight * math.sin(2.0 * math.pi * thump_freq * t) * thump_env

        # Armónicos
        f1 = math.sin(2.0 * math.pi * freq * t)
        f_sub = sub_weight * math.sin(1.0 * math.pi * freq * t)
        f_sub2 = (sub2_weight * math.sin(0.5 * math.pi * freq * t)) if freq > 800 else 0.0

        # Los armónicos altos caen exponencialmente más rápido (física de campanas y maderas)
        h2 = harm2_weight * math.sin(4.0 * math.pi * freq * t) * math.exp(-t * 35.0)
        h3 = harm3_weight * math.sin(6.0 * math.pi * freq * t) * math.exp(-t * 60.0)

        norm = 1.0 + sub_weight + (sub2_weight if freq > 800 else 0) + harm2_weight + harm3_weight + thump_weight
        total_signal = (f1 + f_sub + f_sub2 + h2 + h3 + thump) / norm

        raw_val = amp * env * total_signal
        # Saturación analógica suave
        saturated = math.tanh(raw_val / 16000.0) * 15500.0
        val = int(max(-32767, min(32767, saturated)))
        samples.append(val)

    return samples

def make_material_pop(start_freq, end_freq, duration_ms, amp=8200, sub_freq=160.0, attack_ms=3.0, decay_tau_ms=35.0):
    """Pop acústico de gota líquida / burbuja táctil con cuerpo profundo."""
    total_samples = int(SAMPLE_RATE * (duration_ms / 1000.0))
    att_samples = max(1, int(SAMPLE_RATE * (attack_ms / 1000.0)))
    decay_tau_samples = SAMPLE_RATE * (decay_tau_ms / 1000.0)

    samples = []
    phase = 0.0
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        frac = i / total_samples

        f_inst = start_freq * math.pow(end_freq / start_freq, math.pow(frac, 0.60))
        phase += 2.0 * math.pi * f_inst / SAMPLE_RATE

        if i < att_samples:
            env = 0.5 * (1.0 - math.cos(math.pi * (i / att_samples)))
        else:
            rel_i = i - att_samples
            env = math.exp(-rel_i / decay_tau_samples)

        sub_body = 0.50 * math.sin(2.0 * math.pi * sub_freq * t) * math.exp(-t * 40.0)
        signal = (math.sin(phase) + sub_body) / 1.50

        raw_val = amp * env * signal
        saturated = math.tanh(raw_val / 15000.0) * 14500.0
        val = int(max(-32767, min(32767, saturated)))
        samples.append(val)
    return samples

def make_tactile_click(high_freq, low_freq, duration_ms, amp=7500):
    """Click háptico de interfaz tipo madera / vidrio templado pulido."""
    total_samples = int(SAMPLE_RATE * (duration_ms / 1000.0))
    samples = []
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        env_high = math.exp(-t * 220.0)
        env_low = math.exp(-t * 70.0)
        s_high = 0.35 * math.sin(2.0 * math.pi * high_freq * t) * env_high
        s_low = 0.65 * math.sin(2.0 * math.pi * low_freq * t) * env_low
        val = int(amp * (s_high + s_low))
        val = max(-32767, min(32767, val))
        samples.append(val)
    return samples

def save_wav(filename, samples):
    dest_dir = "/home/nova/.config/panacea/sounds/material"
    os.makedirs(dest_dir, exist_ok=True)
    filepath = os.path.join(dest_dir, filename)
    data = struct.pack(f"<{len(samples)}h", *samples)
    with wave.open(filepath, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(data)
    print(f"Generated {filename:22s}: {len(samples)/SAMPLE_RATE:.3f}s ({len(samples)} samples)")

# ----------------------------------------------------------- GENERADORES
# 1. connect.wav (Do6 -> Sol6 -> Do7: campanas cálidas arpegiadas)
def gen_connect():
    s = make_silence(20)
    s += make_material_tone(P(1046.50), 85.0, amp=7600, attack_ms=4.0, decay_tau_ms=50.0)
    s += make_silence(12)
    s += make_material_tone(P(1567.98), 90.0, amp=7200, attack_ms=4.0, decay_tau_ms=55.0)
    s += make_silence(12)
    s += make_material_tone(P(2093.00), 160.0, amp=6600, attack_ms=4.0, decay_tau_ms=85.0)
    s += make_silence(25)
    save_wav("connect.wav", s)

# 2. disconnect.wav (Do7 -> Sol6 -> Mi6: descenso armónico cálido)
def gen_disconnect():
    s = make_silence(20)
    s += make_material_tone(P(2093.00), 85.0, amp=6600, attack_ms=4.0, decay_tau_ms=50.0)
    s += make_silence(12)
    s += make_material_tone(P(1567.98), 90.0, amp=7200, attack_ms=4.0, decay_tau_ms=55.0)
    s += make_silence(12)
    s += make_material_tone(P(1318.51), 160.0, amp=7600, attack_ms=4.0, decay_tau_ms=85.0)
    s += make_silence(25)
    save_wav("disconnect.wav", s)

# 3. charge.wav (Sol5 -> Do6 -> Sol6: energía ascendente con resonancia)
def gen_charge():
    s = make_silence(15)
    s += make_material_tone(P(783.99), 85.0, amp=8200, attack_ms=5.0, decay_tau_ms=55.0)
    s += make_silence(14)
    s += make_material_tone(P(1046.50), 95.0, amp=8000, attack_ms=5.0, decay_tau_ms=65.0)
    s += make_silence(14)
    s += make_material_tone(P(1567.98), 220.0, amp=7500, attack_ms=5.0, decay_tau_ms=110.0)
    s += make_silence(25)
    save_wav("charge.wav", s)

# 4. mode_powersave.wav (Mi5 -> Do5: marimba cálida, profunda y tranquila)
def gen_mode_powersave():
    s = make_silence(15)
    s += make_material_tone(P(659.25), 110.0, amp=7800, attack_ms=7.0, decay_tau_ms=80.0, sub_weight=0.65)
    s += make_silence(18)
    s += make_material_tone(P(523.25), 180.0, amp=7500, attack_ms=8.0, decay_tau_ms=120.0, sub_weight=0.70)
    s += make_silence(20)
    save_wav("mode_powersave.wav", s)

# 5. mode_balanced.wav (Sol5 -> Do6: equilibrado, moderno y nítido)
def gen_mode_balanced():
    s = make_silence(15)
    s += make_material_tone(P(783.99), 80.0, amp=7800, attack_ms=5.0, decay_tau_ms=60.0)
    s += make_silence(16)
    s += make_material_tone(P(1046.50), 140.0, amp=7800, attack_ms=5.0, decay_tau_ms=90.0)
    s += make_silence(20)
    save_wav("mode_balanced.wav", s)

# 6. mode_performance.wav (Do6 -> Mi6 -> Sol6: tríada ágil con brillo)
def gen_mode_performance():
    s = make_silence(15)
    s += make_material_tone(P(1046.50), 65.0, amp=7500, attack_ms=4.0, decay_tau_ms=45.0)
    s += make_silence(10)
    s += make_material_tone(P(1318.51), 70.0, amp=7500, attack_ms=4.0, decay_tau_ms=50.0)
    s += make_silence(10)
    s += make_material_tone(P(1567.98), 150.0, amp=7200, attack_ms=4.0, decay_tau_ms=90.0)
    s += make_silence(20)
    save_wav("mode_performance.wav", s)

# 7. lock.wav (Bloqueo: pestillo acústico táctil sólido y moderno)
def gen_lock():
    s = make_silence(8)
    # Clic de contacto agudo suave
    s += make_tactile_click(1450.0, 180.0, 24.0, amp=7800)
    s += make_silence(10)
    # Caída al tono grave Sol5 con cuerpo táctil
    s += make_material_tone(P(783.99), 90.0, amp=8200, attack_ms=3.0, decay_tau_ms=45.0, sub_weight=0.70)
    s += make_silence(15)
    save_wav("lock.wav", s)

# 8. unlock.wav (Desbloqueo: liberación acústica ascendente)
def gen_unlock():
    s = make_silence(8)
    # Toque inicial de liberación
    s += make_material_tone(P(783.99), 60.0, amp=7200, attack_ms=3.0, decay_tau_ms=35.0, sub_weight=0.60)
    s += make_silence(10)
    # Chime ascendente Sol6
    s += make_material_tone(P(1567.98), 110.0, amp=7500, attack_ms=3.0, decay_tau_ms=65.0)
    s += make_silence(15)
    save_wav("unlock.wav", s)

# 9. settings_open.wav (Apertura: Do6 -> Mi6 micro-chime suave)
def gen_settings_open():
    s = make_silence(8)
    s += make_material_tone(P(1046.50), 60.0, amp=6800, attack_ms=3.0, decay_tau_ms=40.0)
    s += make_silence(12)
    s += make_material_tone(P(1318.51), 100.0, amp=6800, attack_ms=3.0, decay_tau_ms=60.0)
    s += make_silence(15)
    save_wav("settings_open.wav", s)

# 10. settings_close.wav (Cierre: Mi6 -> Do6 descarte sutil)
def gen_settings_close():
    s = make_silence(8)
    s += make_material_tone(P(1318.51), 60.0, amp=6800, attack_ms=3.0, decay_tau_ms=40.0)
    s += make_silence(12)
    s += make_material_tone(P(1046.50), 100.0, amp=6800, attack_ms=3.0, decay_tau_ms=60.0)
    s += make_silence(15)
    save_wav("settings_close.wav", s)

# 11. batt_full.wav (Mi6 -> Sol6 -> Do7 tríada armónica)
def gen_batt_full():
    s = make_silence(15)
    s += make_material_tone(P(1318.51), 75.0, amp=7200, attack_ms=4.0, decay_tau_ms=50.0)
    s += make_silence(14)
    s += make_material_tone(P(1567.98), 80.0, amp=7200, attack_ms=4.0, decay_tau_ms=55.0)
    s += make_silence(14)
    s += make_material_tone(P(2093.00), 180.0, amp=6800, attack_ms=4.0, decay_tau_ms=100.0)
    s += make_silence(20)
    save_wav("batt_full.wav", s)

# 12. lowbatt.wav (Sol6 -> Do6 doble aviso con cuerpo)
def gen_lowbatt():
    s = make_silence(15)
    s += make_material_tone(P(1567.98), 65.0, amp=7000, attack_ms=4.0, decay_tau_ms=45.0)
    s += make_silence(10)
    s += make_material_tone(P(1046.50), 90.0, amp=7600, attack_ms=4.0, decay_tau_ms=60.0)
    s += make_silence(55)
    s += make_material_tone(P(1567.98), 65.0, amp=7000, attack_ms=4.0, decay_tau_ms=45.0)
    s += make_silence(10)
    s += make_material_tone(P(1046.50), 140.0, amp=7600, attack_ms=4.0, decay_tau_ms=90.0)
    s += make_silence(20)
    save_wav("lowbatt.wav", s)

# 13. notification.wav (Mi6 -> La6 dos gotas de campana armónica)
def gen_notification():
    s = make_silence(15)
    s += make_material_tone(P(1318.51), 80.0, amp=7500, attack_ms=4.0, decay_tau_ms=55.0)
    s += make_silence(16)
    s += make_material_tone(P(1760.00), 160.0, amp=7500, attack_ms=4.0, decay_tau_ms=95.0)
    s += make_silence(20)
    save_wav("notification.wav", s)

# 14. screenshot.wav (Obturador acústico cálido moderno: Do7 -> Sol6)
def gen_screenshot():
    s = make_silence(8)
    s += make_tactile_click(2093.0, 320.0, 22.0, amp=7200)
    s += make_silence(8)
    s += make_material_tone(P(1567.98), 85.0, amp=7500, attack_ms=3.0, decay_tau_ms=50.0)
    s += make_silence(12)
    save_wav("screenshot.wav", s)

# 15. voice_start.wav (Do6 -> Sol6 escucha asistencial Pixel style)
def gen_voice_start():
    s = make_silence(15)
    s += make_material_tone(P(1046.50), 75.0, amp=7200, attack_ms=4.0, decay_tau_ms=50.0)
    s += make_silence(14)
    s += make_material_tone(P(1567.98), 140.0, amp=7200, attack_ms=4.0, decay_tau_ms=85.0)
    s += make_silence(15)
    save_wav("voice_start.wav", s)

# 16. voice_done.wav (Sol6 -> Do6 confirmación asistencial)
def gen_voice_done():
    s = make_silence(15)
    s += make_material_tone(P(1567.98), 70.0, amp=7200, attack_ms=4.0, decay_tau_ms=45.0)
    s += make_silence(12)
    s += make_material_tone(P(1046.50), 150.0, amp=7600, attack_ms=4.0, decay_tau_ms=95.0)
    s += make_silence(15)
    save_wav("voice_done.wav", s)

# 17. island_pop.wav (Pop táctil Dynamic Island: gota acústica profunda 1100Hz -> 380Hz con resonancia a 160Hz)
def gen_island_pop():
    s = make_silence(4)
    s += make_material_pop(1150.0, 420.0, 75.0, amp=8500, sub_freq=160.0, attack_ms=2.5, decay_tau_ms=38.0)
    s += make_silence(6)
    save_wav("island_pop.wav", s)

# 18. tock.wav (Micro-tap táctil de interfaz)
def gen_tock():
    s = make_silence(2)
    s += make_material_tone(P(1318.51), 38.0, amp=6800, attack_ms=2.0, decay_tau_ms=18.0, sub_weight=0.70, thump_weight=0.35)
    s += make_silence(4)
    save_wav("tock.wav", s)

# 19. kbd_light (Teclado LOQ: niveles 0, 1, 2)
def gen_kbd_light():
    # Nivel 0 (Apagado): pop suave descendente
    s0 = make_silence(4)
    s0 += make_material_pop(680.0, 320.0, 65.0, amp=7500, sub_freq=140.0, attack_ms=3.0, decay_tau_ms=35.0)
    s0 += make_silence(5)
    save_wav("kbd_light_0.wav", s0)

    # Nivel 1 (Medio 50%): tono La5 puro y cálido
    s1 = make_silence(5)
    s1 += make_material_tone(P(880.00), 100.0, amp=7600, attack_ms=4.0, decay_tau_ms=65.0, sub_weight=0.60)
    s1 += make_silence(5)
    save_wav("kbd_light_1.wav", s1)

    # Nivel 2 (100%): La5 -> Mi6
    s2 = make_silence(5)
    s2 += make_material_tone(P(880.00), 65.0, amp=7200, attack_ms=3.0, decay_tau_ms=45.0)
    s2 += make_silence(12)
    s2 += make_material_tone(P(1318.51), 120.0, amp=7400, attack_ms=3.0, decay_tau_ms=75.0)
    s2 += make_silence(5)
    save_wav("kbd_light_2.wav", s2)
    save_wav("kbd_light.wav", s2)

# 20. vol_tick.wav (Tick de volumen: gota sutil Re6 / 1174.66 Hz)
def gen_vol_tick():
    s = make_silence(2)
    s += make_material_tone(P(1174.66), 40.0, amp=6200, attack_ms=2.0, decay_tau_ms=18.0, sub_weight=0.60, thump_weight=0.30)
    s += make_silence(2)
    save_wav("vol_tick.wav", s)

if __name__ == "__main__":
    gen_connect()
    gen_disconnect()
    gen_charge()
    gen_mode_powersave()
    gen_mode_balanced()
    gen_mode_performance()
    gen_lock()
    gen_unlock()
    gen_settings_open()
    gen_settings_close()
    gen_batt_full()
    gen_lowbatt()
    gen_notification()
    gen_screenshot()
    gen_voice_start()
    gen_voice_done()
    gen_island_pop()
    gen_tock()
    gen_kbd_light()
    gen_vol_tick()
    print("All Material You sounds successfully generated!")
