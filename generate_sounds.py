#!/usr/bin/env python3
"""
Generador Maestro Acústico Forense de Efectos de Sonido para Panacea Shell.
Incluye:
- connect & disconnect (recreación pura)
- charge (energía ascendente)
- mode_powersave (modo tranquilo: suave, cálido, pacífico)
- mode_balanced (modo equilibrado: claro, estable)
- mode_performance (modo rendimiento: rápido, enérgico, ascendente)
- lock & unlock (cerrojo digital firme y liberación)
- settings_close (descarte sutil Super+I)
- batt_full & lowbatt (tríada y doble advertencia)
- notification (doble bit amigable)
- screenshot (obturador digital rápido)
- voice_start & voice_done (aviso de escucha y confirmación)
- island_pop (pop táctil con presencia y cuerpo real, no un pixel)
- tock (impulso háptico de UI)
"""

import math
import struct
import wave
import os

SAMPLE_RATE = 48000
PITCH_SCALE = 0.99

def P(f):
    return f * PITCH_SCALE

def make_forensic_bit(freq, duration_ms, sustain_amp, attack_peak=None, attack_ms=1.0, decay_ms=4.5, sub_warmth=0.0):
    """
    Sintetizador acústico forense que replica la física de connect.wav.
    """
    if attack_peak is None:
        attack_peak = sustain_amp

    num_samples = int(SAMPLE_RATE * (duration_ms / 1000.0))
    att_samples = max(1, int(SAMPLE_RATE * (attack_ms / 1000.0)))
    dec_samples = max(1, int(SAMPLE_RATE * (decay_ms / 1000.0)))
    sus_samples = max(0, num_samples - att_samples - dec_samples)
    trans_samples = int(SAMPLE_RATE * 0.003)

    samples = []
    for i in range(num_samples):
        if i < att_samples:
            env = 0.5 * (1.0 - math.cos(math.pi * (i / att_samples)))
            amp = attack_peak * env
        elif i < att_samples + sus_samples:
            rel_trans = i - att_samples
            if rel_trans < trans_samples:
                frac = rel_trans / trans_samples
                amp = sustain_amp + (attack_peak - sustain_amp) * math.exp(-3.0 * frac)
            else:
                amp = sustain_amp
        else:
            rel_i = i - (att_samples + sus_samples)
            env = 0.5 * (1.0 + math.cos(math.pi * (rel_i / dec_samples)))
            amp = sustain_amp * env

        # Onda base con toque de calidez opcional para modos tranquilos
        t = i / SAMPLE_RATE
        wave_val = math.sin(2.0 * math.pi * freq * t)
        if sub_warmth > 0:
            wave_val = (wave_val + sub_warmth * math.sin(1.0 * math.pi * freq * t)) / (1.0 + sub_warmth)

        val = int(amp * env * wave_val)
        val = max(-32767, min(32767, val))
        samples.append(val)
    return samples

def make_silence(duration_ms):
    return [0] * int(SAMPLE_RATE * (duration_ms / 1000.0))

def make_pop(start_freq, end_freq, duration_ms, amp=5200, attack_ms=1.5, decay_ms=18.0):
    """Pop táctil para la isla dinámica con cuerpo acústico y presencia real."""
    num_samples = int(SAMPLE_RATE * (duration_ms / 1000.0))
    att_samples = max(1, int(SAMPLE_RATE * (attack_ms / 1000.0)))
    dec_samples = max(1, int(SAMPLE_RATE * (decay_ms / 1000.0)))
    sus_samples = max(0, num_samples - att_samples - dec_samples)

    samples = []
    phase = 0.0
    for i in range(num_samples):
        frac = i / num_samples
        # Caída suave con resonancia de burbuja táctil
        f_inst = start_freq * math.pow(end_freq / start_freq, math.pow(frac, 0.7))
        phase += 2.0 * math.pi * f_inst / SAMPLE_RATE

        if i < att_samples:
            env = 0.5 * (1.0 - math.cos(math.pi * (i / att_samples)))
        elif i < att_samples + sus_samples:
            env = 1.0
        else:
            rel_i = i - (att_samples + sus_samples)
            env = 0.5 * (1.0 + math.cos(math.pi * (rel_i / dec_samples)))

        # Subarmónico cálido para que no sea un 'pixel' fino
        wave_val = math.sin(phase) + 0.25 * math.sin(phase * 0.5)
        val = int(amp * env * wave_val / 1.25)
        val = max(-32767, min(32767, val))
        samples.append(val)
    return samples

def save_wav(filename, samples):
    sounds_dir = os.environ.get("PANACEA_SOUNDS_DIR") or os.path.join(os.environ.get("PANACEA_DIR", os.path.expanduser("~/.config/panacea")), "sounds")
    if not os.path.isdir(sounds_dir):
        sounds_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sounds")
    os.makedirs(sounds_dir, exist_ok=True)
    path = os.path.join(sounds_dir, filename)
    data = struct.pack(f"<{len(samples)}h", *samples)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(data)
    print(f"Generated {filename:20s}: {len(samples)/SAMPLE_RATE:.3f}s, {len(samples)} samples")

# 1. connect.wav (Bluetooth)
def gen_connect():
    s = make_silence(80)
    s += make_forensic_bit(P(1046.50), 52.3, sustain_amp=4560, attack_peak=4690)
    s += make_silence(46.8)
    s += make_forensic_bit(P(1567.98), 56.0, sustain_amp=2150, attack_peak=2660)
    s += make_silence(44.0)
    s += make_forensic_bit(P(2093.00), 53.2, sustain_amp=1140, attack_peak=1910)
    s += make_silence(25)
    save_wav("connect.wav", s)

# 2. disconnect.wav (Bluetooth)
def gen_disconnect():
    s = make_silence(80)
    s += make_forensic_bit(P(2093.00), 53.0, sustain_amp=1140, attack_peak=1910)
    s += make_silence(44.0)
    s += make_forensic_bit(P(1567.98), 56.0, sustain_amp=2150, attack_peak=2660)
    s += make_silence(46.8)
    s += make_forensic_bit(P(1318.51), 54.0, sustain_amp=4420, attack_peak=4420)
    s += make_silence(25)
    save_wav("disconnect.wav", s)

# 3. charge.wav (Carga AC propia)
def gen_charge():
    s = make_silence(20)
    s += make_forensic_bit(P(783.99), 50.0, sustain_amp=4800, attack_peak=4800)
    s += make_silence(36.0)
    s += make_forensic_bit(P(1046.50), 52.0, sustain_amp=4200, attack_peak=4600)
    s += make_silence(36.0)
    s += make_forensic_bit(P(1567.98), 95.0, sustain_amp=2400, attack_peak=3200, decay_ms=25.0)
    s += make_silence(20)
    save_wav("charge.wav", s)

# 4. mode_powersave.wav (Modo Tranquilo / Ahorro)
# 'Que el tranquilo suene tranquilo': tonos cálidos, graves, suaves y relajados
def gen_mode_powersave():
    s = make_silence(20)
    s += make_forensic_bit(P(659.25), 65.0, sustain_amp=3800, attack_peak=3800, attack_ms=2.5, decay_ms=20.0, sub_warmth=0.3)
    s += make_silence(30.0)
    s += make_forensic_bit(P(523.25), 95.0, sustain_amp=3600, attack_peak=3600, attack_ms=3.0, decay_ms=35.0, sub_warmth=0.35)
    s += make_silence(25)
    save_wav("mode_powersave.wav", s)

# 5. mode_balanced.wav (Modo Equilibrado / Balanceado)
# Tono neutro, claro y ordenado: Sol5 -> Do6
def gen_mode_balanced():
    s = make_silence(20)
    s += make_forensic_bit(P(783.99), 45.0, sustain_amp=4400, attack_peak=4500)
    s += make_silence(30.0)
    s += make_forensic_bit(P(1046.50), 65.0, sustain_amp=4200, attack_peak=4400, decay_ms=18.0)
    s += make_silence(20)
    save_wav("mode_balanced.wav", s)

# 6. mode_performance.wav (Modo Rendimiento / Máximo)
# Enérgico, veloz y ascendente: Do6 -> Mi6 -> Sol6
def gen_mode_performance():
    s = make_silence(15)
    s += make_forensic_bit(P(1046.50), 38.0, sustain_amp=4000, attack_peak=4400)
    s += make_silence(22.0)
    s += make_forensic_bit(P(1318.51), 38.0, sustain_amp=3600, attack_peak=4000)
    s += make_silence(22.0)
    s += make_forensic_bit(P(1567.98), 65.0, sustain_amp=2600, attack_peak=3400, decay_ms=18.0)
    s += make_silence(15)
    save_wav("mode_performance.wav", s)

# 7. lock.wav (Bloqueo)
def gen_lock():
    s = make_silence(10)
    s += make_forensic_bit(P(1567.98), 24.0, sustain_amp=2400, attack_peak=3200)
    s += make_silence(18.0)
    s += make_forensic_bit(P(783.99), 44.0, sustain_amp=4600, attack_peak=4800, decay_ms=14.0)
    s += make_silence(10)
    save_wav("lock.wav", s)

# 8. unlock.wav (Desbloqueo)
def gen_unlock():
    s = make_silence(10)
    s += make_forensic_bit(P(783.99), 24.0, sustain_amp=4400, attack_peak=4600)
    s += make_silence(18.0)
    s += make_forensic_bit(P(1567.98), 44.0, sustain_amp=2600, attack_peak=3200, decay_ms=14.0)
    s += make_silence(10)
    save_wav("unlock.wav", s)

# 9. settings_open.wav (Apertura Super + I - Simetría exacta con cierre)
# Ascenso Do6 -> Mi6 con la misma duración, tímbrica y envolvente que el cierre (Mi6 -> Do6)
def gen_settings_open():
    s = make_silence(10)
    s += make_forensic_bit(P(1046.50), 32.0, sustain_amp=4400, attack_peak=4500)
    s += make_silence(24.0)
    s += make_forensic_bit(P(1318.51), 48.0, sustain_amp=3600, attack_peak=4000, decay_ms=16.0)
    s += make_silence(15)
    save_wav("settings_open.wav", s)

# 10. settings_close.wav (Cierre Super + I)
def gen_settings_close():
    s = make_silence(10)
    s += make_forensic_bit(P(1318.51), 32.0, sustain_amp=3600, attack_peak=4000)
    s += make_silence(24.0)
    s += make_forensic_bit(P(1046.50), 48.0, sustain_amp=4400, attack_peak=4500, decay_ms=16.0)
    s += make_silence(15)
    save_wav("settings_close.wav", s)

# 10. batt_full.wav (Carga 80% / 100%)
def gen_batt_full():
    s = make_silence(25)
    s += make_forensic_bit(P(1318.51), 48.0, sustain_amp=3800, attack_peak=4200)
    s += make_silence(36.0)
    s += make_forensic_bit(P(1567.98), 50.0, sustain_amp=2600, attack_peak=3100)
    s += make_silence(36.0)
    s += make_forensic_bit(P(2093.00), 75.0, sustain_amp=1500, attack_peak=2200, decay_ms=22.0)
    s += make_silence(20)
    save_wav("batt_full.wav", s)

# 11. lowbatt.wav (Batería Baja)
def gen_lowbatt():
    s = make_silence(20)
    s += make_forensic_bit(P(1567.98), 36.0, sustain_amp=2400, attack_peak=2900)
    s += make_silence(26.0)
    s += make_forensic_bit(P(1046.50), 46.0, sustain_amp=4400, attack_peak=4600)
    s += make_silence(65.0)
    s += make_forensic_bit(P(1567.98), 36.0, sustain_amp=2400, attack_peak=2900)
    s += make_silence(26.0)
    s += make_forensic_bit(P(1046.50), 60.0, sustain_amp=4400, attack_peak=4600, decay_ms=18.0)
    s += make_silence(20)
    save_wav("lowbatt.wav", s)

# 12. notification.wav (Notificación de sistema)
def gen_notification():
    s = make_silence(20)
    s += make_forensic_bit(P(1318.51), 40.0, sustain_amp=3800, attack_peak=4200)
    s += make_silence(28.0)
    s += make_forensic_bit(P(1760.00), 60.0, sustain_amp=2600, attack_peak=3200, decay_ms=18.0)
    s += make_silence(20)
    save_wav("notification.wav", s)

# 13. screenshot.wav (Captura de pantalla: obturador digital con presencia)
def gen_screenshot():
    s = make_silence(10)
    s += make_forensic_bit(P(2093.00), 20.0, sustain_amp=1500, attack_peak=2800)
    s += make_silence(12.0)
    s += make_forensic_bit(P(1567.98), 38.0, sustain_amp=2600, attack_peak=3400, decay_ms=16.0)
    s += make_silence(10)
    save_wav("screenshot.wav", s)

# 14. voice_start.wav (Inicio de voz: chime de escucha ascendente)
def gen_voice_start():
    s = make_silence(20)
    s += make_forensic_bit(P(1046.50), 42.0, sustain_amp=4200, attack_peak=4400)
    s += make_silence(28.0)
    s += make_forensic_bit(P(1567.98), 65.0, sustain_amp=2600, attack_peak=3200, decay_ms=22.0)
    s += make_silence(20)
    save_wav("voice_start.wav", s)

# 15. voice_done.wav (Fin de voz: chime de confirmación descendente)
def gen_voice_done():
    s = make_silence(20)
    s += make_forensic_bit(P(1567.98), 38.0, sustain_amp=2600, attack_peak=3200)
    s += make_silence(24.0)
    s += make_forensic_bit(P(1046.50), 65.0, sustain_amp=4200, attack_peak=4400, decay_ms=25.0)
    s += make_silence(20)
    save_wav("voice_done.wav", s)

# 16. island_pop.wav (Pop táctil Dynamic Island: cuerpo sustancial de 65ms, no un pixel)
def gen_island_pop():
    s = make_silence(5)
    s += make_pop(P(1750.0), P(580.0), 65.0, amp=5000, attack_ms=1.5, decay_ms=22.0)
    s += make_silence(5)
    save_wav("island_pop.wav", s)

# 17. tock.wav (Micro-tick háptico táctil con presencia)
def gen_tock():
    s = make_silence(2)
    s += make_forensic_bit(P(1318.51), 22.0, sustain_amp=3400, attack_peak=4400, attack_ms=0.8, decay_ms=10.0)
    s += make_silence(2)
    save_wav("tock.wav", s)

# 18. kbd_light (Notificador de brillo de teclado LOQ: 0% / 50% / 100%)
# Sonidos sutiles, micro-acústicos y elegantes
def gen_kbd_light():
    # Nivel 0 (Apagado / 0%): suave descenso sutil a reposo con cuerpo táctil
    s0 = make_silence(5)
    s0 += make_pop(P(880.0), P(440.0), 55.0, amp=5000, attack_ms=1.5, decay_ms=28.0)
    s0 += make_silence(5)
    save_wav("kbd_light_0.wav", s0)

    # Nivel 1 (50% / Medio): tono Nothing centrado, nítido y con presencia acústica
    s1 = make_silence(5)
    s1 += make_forensic_bit(P(880.00), 50.0, sustain_amp=4800, attack_peak=5200, attack_ms=1.5, decay_ms=24.0, sub_warmth=0.2)
    s1 += make_silence(5)
    save_wav("kbd_light_1.wav", s1)

    # Nivel 2 (100% / Máximo): destello armónico ascendente (La5 -> Mi6)
    s2 = make_silence(5)
    s2 += make_forensic_bit(P(880.00), 32.0, sustain_amp=4400, attack_peak=4800, attack_ms=1.0, decay_ms=12.0)
    s2 += make_silence(18.0)
    s2 += make_forensic_bit(P(1318.51), 52.0, sustain_amp=3800, attack_peak=4600, attack_ms=1.0, decay_ms=22.0)
    s2 += make_silence(5)
    save_wav("kbd_light_2.wav", s2)

    # Fallback genérico sutil kbd_light.wav
    save_wav("kbd_light.wav", s2)

# 19. vol_tick.wav (Pip sutil de referencia de volumen)
# Micro-pulso puro y limpio para dar referencia auditiva al subir/bajar volumen
def gen_vol_tick():
    s = make_silence(2)
    s += make_forensic_bit(P(1174.66), 24.0, sustain_amp=2600, attack_peak=3200, attack_ms=1.0, decay_ms=12.0)
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
    print("Master comprehensive sound suite generated with 100% precision!")
