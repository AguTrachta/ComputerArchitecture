#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Cliente UART para enviar 3 instrucciones (ADDI + ADDI + ADD)
y mostrar los 3 resultados devueltos por la FPGA.
Detecta automáticamente los puertos seriales.
"""

import serial
import serial.tools.list_ports
import time

# ------------------------------------
# Configuración UART (8N1, 9600 baud)
# ------------------------------------
BAUD_RATE = 9600
BYTESIZE = serial.EIGHTBITS
PARITY   = serial.PARITY_NONE
STOPBITS = serial.STOPBITS_ONE

# ------------------------------------
# Codificación R e I-type
# ------------------------------------
OPCODE_RTYPE = 0b0110011
OPCODE_ITYPE = 0b0010011

ENCODINGS_R = {
    "add": (0b0000000, 0b000),
    "sub": (0b0100000, 0b000),
    "and": (0b0000000, 0b111),
    "or" : (0b0000000, 0b110),
    "xor": (0b0000000, 0b100),
    "srl": (0b0000000, 0b101),
    "sra": (0b0100000, 0b101),
}

ENCODINGS_I = {
    "addi": 0b000,
    "andi": 0b111,
    "ori" : 0b110,
    "xori": 0b100,
}

# ------------------------------------
# Funciones auxiliares
# ------------------------------------
def list_serial_ports():
    """Lista los puertos seriales disponibles y permite elegir uno."""
    ports = serial.tools.list_ports.comports()
    if not ports:
        print("⚠️  No se encontraron puertos seriales.")
        exit(1)

    print("\n=== Puertos seriales detectados ===")
    for i, p in enumerate(ports):
        desc = p.description or "Sin descripción"
        print(f"[{i}] {p.device} — {desc}")
    print("===================================")

    while True:
        try:
            sel = int(input(f"Seleccione puerto (0-{len(ports)-1}): "))
            if 0 <= sel < len(ports):
                return ports[sel].device
        except ValueError:
            pass
        print("Entrada inválida. Intente nuevamente.")


def encode_itype(mnemonic: str, rd: int, rs1: int, imm: int) -> int:
    funct3 = ENCODINGS_I[mnemonic]
    imm &= 0xFFF
    return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | OPCODE_ITYPE


def encode_rtype(mnemonic: str, rd: int, rs1: int, rs2: int) -> int:
    funct7, funct3 = ENCODINGS_R[mnemonic]
    return ((funct7 & 0x7F) << 25) | \
           ((rs2 & 0x1F) << 20) | \
           ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x07) << 12) | \
           ((rd & 0x1F) << 7) | \
           (OPCODE_RTYPE & 0x7F)


def send_instruction(ser: serial.Serial, instr: int):
    """Envía 4 bytes little-endian."""
    ser.write(instr.to_bytes(4, "little"))
    ser.flush()


def read_result_byte(ser: serial.Serial, timeout_s: float = 1.0):
    """Lee 1 byte de resultado (bloqueante hasta timeout)."""
    t0 = time.time()
    while time.time() - t0 < timeout_s:
        if ser.in_waiting:
            return ser.read(1)[0]
        time.sleep(0.001)
    return None


# ------------------------------------
# Programa principal
# ------------------------------------
def main():
    port = list_serial_ports()

    print(f"\nConectando a {port} @ {BAUD_RATE} baud (8N1)...\n")
    ser = serial.Serial(
        port,
        BAUD_RATE,
        bytesize=BYTESIZE,
        parity=PARITY,
        stopbits=STOPBITS,
        timeout=1.0
    )

    time.sleep(0.05)

    try:
        # 1️⃣ ADDI x1, x0, 5
        instr1 = encode_itype("addi", 1, 0, 5)
        print("→ Enviando: ADDI x1, x0, 5")
        send_instruction(ser, instr1)
        res1 = read_result_byte(ser)
        print(f"   Resultado recibido: {res1 if res1 is not None else 'Sin respuesta'}")

        # 2️⃣ ADDI x2, x0, 10
        instr2 = encode_itype("addi", 2, 0, 10)
        print("→ Enviando: ADDI x2, x0, 10")
        send_instruction(ser, instr2)
        res2 = read_result_byte(ser)
        print(f"   Resultado recibido: {res2 if res2 is not None else 'Sin respuesta'}")

        # 3️⃣ ADD x3, x1, x2
        instr3 = encode_rtype("add", 3, 1, 2)
        print("→ Enviando: ADD x3, x1, x2")
        send_instruction(ser, instr3)
        res3 = read_result_byte(ser)
        print(f"   Resultado recibido: {res3 if res3 is not None else 'Sin respuesta'}")

        print("\n===============================")
        print("Resumen:")
        print(f"  x1 = {res1 if res1 is not None else '---'}")
        print(f"  x2 = {res2 if res2 is not None else '---'}")
        print(f"  x3 = {res3 if res3 is not None else '---'} (suma)")
        print("===============================\n")

    finally:
        ser.close()
        print(f"Puerto {port} cerrado.\n")


if __name__ == "__main__":
    main()
