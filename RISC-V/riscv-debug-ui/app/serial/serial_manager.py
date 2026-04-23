from __future__ import annotations

from typing import List, Optional

import serial
import serial.tools.list_ports


class RealSerialManager:
    def __init__(self) -> None:
        self.ser: Optional[serial.Serial] = None

    def get_ports(self) -> List[str]:
        ports = serial.tools.list_ports.comports()
        return [port.device for port in ports]

    def connect(self, port: str, baudrate: int = 9600) -> None:
        if self.ser and self.ser.is_open:
            self.disconnect()

        self.ser = serial.Serial(
            port=port,
            baudrate=baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0,
            write_timeout=1,
        )
        self.ser.reset_input_buffer()
        self.ser.reset_output_buffer()

    def disconnect(self) -> None:
        if self.ser and self.ser.is_open:
            self.ser.close()
        self.ser = None

    def is_connected(self) -> bool:
        return self.ser is not None and self.ser.is_open

    def write(self, data: bytes) -> int:
        if not self.is_connected():
            raise RuntimeError("No hay un puerto serial conectado.")
        return self.ser.write(data)

    def read(self, size: int) -> bytes:
        if not self.is_connected():
            return b""
        return self.ser.read(size)

    def read_available(self, max_bytes: int = 256) -> bytes:
        if not self.is_connected():
            return b""

        pending = self.ser.in_waiting
        if pending <= 0:
            return b""

        return self.ser.read(min(max_bytes, pending))


serial_manager = RealSerialManager()
