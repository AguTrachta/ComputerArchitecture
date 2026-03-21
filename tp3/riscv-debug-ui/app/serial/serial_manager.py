import serial
import serial.tools.list_ports
from typing import List, Optional

class RealSerialManager:
    def __init__(self):
        self.ser: Optional[serial.Serial] = None

    def get_ports(self) -> List[str]:
        ports = serial.tools.list_ports.comports()
        return [port.device for port in ports]

    def connect(self, port: str, baudrate: int = 9600):
        if self.ser and self.ser.is_open:
            self.disconnect()
        
        # Configuracion 8N1 como exige la FPGA
        self.ser = serial.Serial(
            port=port,
            baudrate=baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1
        )
        print(f"[Serial] Puerto {port} abierto exitosamente a {baudrate} baud.")

    def disconnect(self):
        if self.ser and self.ser.is_open:
            self.ser.close()
            print("[Serial] Puerto cerrado.")
        self.ser = None

    def is_connected(self) -> bool:
        return self.ser is not None and self.ser.is_open

    def write(self, data: bytes):
        if self.is_connected():
            self.ser.write(data)
            print(f"[Serial TX] {data.hex()}")

    def read(self, size: int) -> bytes:
        if self.is_connected():
            data = self.ser.read(size)
            if data:
                print(f"[Serial RX] {data.hex()}")
            return data
        return b''

serial_manager = RealSerialManager()
