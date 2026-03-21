# app/serial/protocol_manager.py
from app.serial.serial_manager import serial_manager
import struct

class ProtocolManager:
    # Definimos opcodes base para el MVP hasta que se documente el RTL detallado
    CMD_RUN = b'\x10'
    CMD_STOP = b'\x11'
    CMD_STEP = b'\x12'
    CMD_LOAD_IMEM = b'\x20'
    CMD_CLEAR_IMEM = b'\x21'
    CMD_DUMP_REGS = b'\x30'
    CMD_DUMP_PIPE = b'\x31'
    CMD_DUMP_MEM = b'\x32'

    def send_run(self):
        serial_manager.write(self.CMD_RUN)

    def send_stop(self):
        serial_manager.write(self.CMD_STOP)

    def send_step(self):
        serial_manager.write(self.CMD_STEP)

    def clear_imem(self):
        serial_manager.write(self.CMD_CLEAR_IMEM)

    def dump_regs(self):
        serial_manager.write(self.CMD_DUMP_REGS)
        
    def dump_pipeline(self):
        serial_manager.write(self.CMD_DUMP_PIPE)
        
    def dump_memory(self):
        serial_manager.write(self.CMD_DUMP_MEM)

    def program_words(self, words: list[int]):
        serial_manager.write(self.CMD_LOAD_IMEM)
        # Enviar las words empaquetadas en 32 bits little-endian
        for w in words:
            packed = struct.pack('<I', w)
            serial_manager.write(packed)

protocol_manager = ProtocolManager()
