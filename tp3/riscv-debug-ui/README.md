# RISC-V Debug UI

Bienvenido al sistema **RISC-V Debug UI**, una pieza de software *Full-Stack* (Interfáz de Usuario + Driver de Comunicación) diseñada para inyectar programas en ROM y extraer el estado interno completo y en tiempo real del pipeline de un procesador RISC-V operando nativamente en una FPGA.

---

## 🏗️ Arquitectura General Implementada

El sistema se ejecuta en un modelo unificado servidor-cliente pero lógicamente desacoplado según lo definido original en la especificación arquitectónica (`docs/ARQUITECTURA_FRONTEND_BACKEND.md`):

1. **Frontend (`frontend/`)**: 
   - Vista interactiva pura en Vanilla JS/CSS ("Glassmorphism Dark Layout").
   - Utiliza llamadas `fetch` nativas para consumir la API REST del backend con promesas asíncronas.
   - Conexión persistente mediante instancias de `WebSocket` puro para recibir eventos emitidos (UART logs, dumps de hardware).
   - El DOM reacciona a la propagación del flujo de WebSockets en tiempo real sin recargar jamás la página.

2. **Backend (`app/`)**: 
   - Desarrollado en **Python 3.10+ (FastAPI)** y gestionado rápidamente mediante `uv`.
   - **`serial_manager.py`**: Interfaz nativa `pyserial` que detecta puertos COM físicos presentes, abriendo el canal de 8 Bits + Parity None a `9600 baud`.
   - **`protocol_manager.py`**: Convierte acciones HTTP a *Raw Bytes* de control enviados a la placa.
   - **`assembler.py`**: Módulo base interceptor del String ASM (preparado estructuralmente para limitar a 1024 instrucciones y transpolar).
   - **Background Async UART Listener**: Un *worker loop* interno en la app FastApi que bloquea imperceptiblemente esperando bits entrantes de la FPGA, y los reparte por toda la red de `WebSocket Broadcast` al vuelo.

---

## ⚡ Ejecutar el Sistema: Un Solo Comando 

Para simplificar el uso y evitar dolores de cabeza con validadores de origen de recursos cruzados (CORS), FastAPI absorbe y entrega el Frontend estáticamente en la URL base.

Para arrancar todo el sistema integrado:

1. Posicionate en la terminal sobre la carpeta raíz (`riscv-debug-ui`):
   ```bash
   cd riscv-debug-ui
   ```
2. Resolvé las capas Python e iniciá el servidor ASGI (`uvicorn`) de un solo golpe:
   ```bash
   uv pip install -e .
   uv run uvicorn app.main:app --reload --port 8080
   ```
3. Dirígete en cualquier navegador moderno a: **`http://localhost:8080/`**

---

## 🗺️ Roadmap Técnico Restante (Según Especificaciones Finales)

Al cotejar el avance estructural real provisto con el documento dictaminador `ARQUITECTURA_FRONTEND_BACKEND.md`, hemos dado por consolidados los Puntos de la fase de planeamiento **Wireframe (UI)**,  **Infraestructura Backend WebSockets/FastAPI** (Python y pyserial) y **Layout Vanilla SPA** (Frontend nativo asincrónico directo).

El tramo de **Acople Final FPGA-Software** consta de los siguientes 4 puntos técnicos inamovibles para ser declarados listos para producción:

### 1. Modelado Crítico de Datos (Pydantic / Encoders)
- *Referencia Doc: Sección 11 y 24.3.*
- Aterrizar y estandarizar formalmente en el servidor las estructuras JSON solicitadas creando los modelos `app/models/dumps.py` y `app/models/responses.py` en Pydantic. Las estructuras del *Pipeline* de 5 Etapas del RTL y los 32 Registros deben ser tipadas estrictamente aquí en Python.

### 2. Máquina de Estados UART en el Backend (RX Parser)
- *Referencia Doc: Sección 6.2.*
- Actualmente `main.py` agarra de a 1 Byte (`serial.read(1)`) y lo inyecta como texto *hex-crudo* al Websocket de la Interfaz. Necesitamos evolucionar `app/serial/protocol_manager.py` con una rutina o máquina de estados descodificadora nativa que analice Header, Payload Largo y Finalización de Trama, traduzca ese grupo consecutivo de valores a nuestros modelos Pydantic (Registros o Memoria) y ahí recién, inyectar el *Dump finalizado y validado* al Frontend Web.

### 3. Implementación Efectiva de Traducción Assembler
- *Referencia Doc: 10.4 ProgramManager / Assembler.*
- Desplazar el comportamiento simulado que asiste la interfaz (inyectado de NOPs) dentro de `app/program/assembler.py` e intercambiarlo por la lógica nativa de tu intérprete ensamblador (ya sea linkeando al proceso `riscv32-unknown-elf-gcc` u otro script local). Validar que la compilación de strings finalice entregando un arreglo de words listos de 32 Bits conformando el límite en piedra dictado de `1024 instrucciones / 4096 bytes`.

### 4. Definición y Acople del Comportamiento Operativo RTL Real
- *Referencia Doc: Sección 7.4.*
- Sentarnos con código Verilog en mano para validar qué capacidades experimentales incluidas en la UI hoy (por ejemplo observar variables puntuales en los Latches como `ID/EX` y `EX/MEM` o limpiezas asíncronas *Clear DMEM*) están listas para salir y programadas en la FPGA. Si la lógica del Silicio no se equipara a los *Dumps* creados en nuestro Endpoint de la Interfaz, estas deberán esconderse detrás de flags (ej `capabilities["can_dump_pipeline"] = False`).
