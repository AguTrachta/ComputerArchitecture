# RISC-V Debug UI

Frontend + backend local para programar la IMEM del core RISC-V por UART, controlar la ejecucion y visualizar el estado observable que expone la Debug Unit.

## Arquitectura

- `frontend/`: SPA en HTML/CSS/Vanilla JS. Consume REST para operaciones discretas y WebSocket para eventos en tiempo real.
- `app/`: backend FastAPI en Python. Contiene el manejo de estado, protocolo UART, assembler y publicacion de eventos.
- `docs/ARQUITECTURA_FRONTEND_BACKEND.md`: documento de referencia de la arquitectura y roadmap.

## Ejecutar

```bash
cd riscv-debug-ui
uv pip install -e .
uv run uvicorn app.main:app --reload --port 8080
```

Abrir `http://localhost:8080/`.

## Estado Del Roadmap

- [x] Punto 1: modelado de datos tipado con Pydantic.
- [x] Punto 2: parser UART RX real alineado con `rt1/core/debug_unit.v`.
- [x] Punto 3: assembler local RV32I en el backend.
- [x] Punto 4: dump real de latches y dump real de memoria integrados en la UI.

## Lo Implementado En Esta Iteracion

### 1. Modelos y estado tipado

Se agregaron:

- `app/models/requests.py`
- `app/models/responses.py`
- `app/models/dumps.py`

El backend ahora tipa:

- estado de sesion
- capacidades declaradas por software
- dump de registros
- dump de pipeline
- dump de memoria
- respuestas de validacion, ensamblado, carga y control

`app/core/state.py` tambien guarda:

- si hay programa cargado
- cantidad de instrucciones cargadas
- cantidad de steps ejecutados
- ultimo error
- ultimos dumps recibidos

### 2. Protocolo UART real

`app/serial/protocol_manager.py` ya no usa opcodes inventados ni envia words little-endian.

Comandos alineados con el RTL:

- `CMD_PROG_BEGIN = 0x10`
- `CMD_RUN = 0x20`
- `CMD_STEP = 0x21`
- `CMD_STOP = 0x22`
- `CMD_DUMP_REGS = 0x30`
- `CMD_DUMP_LATCHES = 0x31`
- `CMD_DUMP_MEM = 0x32`
- `CMD_CLEAR_IMEM = 0x40`

ACKs y respuestas parseadas:

- `C0` clear IMEM ok
- `C1` program ok
- `C2` step ok
- `C3` stop ok
- `C4` run end
- `D0 + 128 bytes + D5` dump de 32 registros
- `D1 + 100 bytes + D5` dump real de 25 words de latches del pipeline
- `D2 + 4096 bytes + D5` dump real de 1024 words de memoria de datos

Detalles relevantes:

- La carga de programa envia longitud en 2 bytes big-endian.
- Cada instruccion se transmite como word de 32 bits big-endian.
- El listener UART ahora consume bytes disponibles sin bloquear el event loop.
- Los eventos WebSocket que salen del backend ya son estructurados: `uart_tx`, `uart_rx`, `backend_state`, `regs_dump`, `pipeline_dump`, `mem_dump`, `warning`, `error`.

### 3. Assembler local

`app/program/assembler.py` reemplaza el mock que devolvia NOPs.

Backend de ensamblado:

- si el sistema encuentra un toolchain GNU RISC-V (`riscv*-gcc` + `objcopy`), lo usa automaticamente
- si no lo encuentra, cae al ensamblador local incluido en Python
- tambien se puede forzar la deteccion con `RISCV_GNU_GCC` y `RISCV_OBJCOPY`

Subset RV32I soportado:

- R-type: `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`, `or`, `and`
- I-type: `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli`, `srli`, `srai`
- Loads/stores: `lb`, `lh`, `lw`, `lbu`, `lhu`, `sb`, `sh`, `sw`
- Control flow: `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`, `jal`, `jalr`
- U-type: `lui`, `auipc`
- Pseudoinstrucciones de una sola word: `nop`, `j`, `jr`, `ret`, `mv`, `halt`
- Directiva: `.word`

Tambien incluye:

- labels en dos pasadas
- registros `x0..x31` alineados con la nomenclatura usada en el RTL
- validacion de rango de inmediatos y offsets
- chequeo del limite de `1024` instrucciones de IMEM

## Cambios En La API

### Programa

- `POST /api/program/validate`: devuelve errores, warnings, cantidad de instrucciones y uso de IMEM.
- `POST /api/program/assemble`: devuelve el listing hex y las words ensambladas.
- `POST /api/program/load`: ensambla, programa por UART y espera `RESP_OK_PROG`.
- `POST /api/program/clear-imem`: espera `RESP_OK_CLEAR`.

### Control

- `POST /api/control/run`: envia `CMD_RUN` y deja el backend en `RUNNING`.
- `POST /api/control/stop`: espera `RESP_OK_STOP`.
- `POST /api/control/step`: espera `RESP_OK_STEP` y luego dispara automaticamente `dump_regs` y `dump_pipeline`.

### Dumps

- `POST /api/dump/regs`: espera y devuelve el dump estructurado.
- `POST /api/dump/pipeline`: devuelve el dump real de latches parseado desde `RESP_DUMP_LATCH`.
- `POST /api/dump/memory`: devuelve una ventana estructurada del dump real de memoria parseado desde `RESP_DUMP_MEM`.

### Estado

- `GET /status`: devuelve conexion, estado CPU, programa cargado, capacidades y ultimos dumps.

## Frontend

La UI ya no depende de mocks para `step` ni memoria.

Cambios concretos:

- sincroniza el estado inicial desde `GET /status`
- conecta/desconecta WebSocket en base al estado real de conexion
- habilita o deshabilita botones segun:
  - conexion
  - estado CPU
  - programa cargado
  - capacidades declaradas
- consume dumps reales de registros
- consume dump real de pipeline/latches en las etapas `Global`, `IF/ID`, `ID/EX`, `EX/MEM` y `MEM/WB`
- consume dump real de memoria y lo pagina por offset en la pestaña `Mem`
- el editor carga por defecto ASM valido para el assembler implementado
- la pagina queda fija en viewport y el scroll de la pestaña `Regs` ocurre dentro de su propia tabla

## Limitaciones Vigentes

- El dump de memoria devuelve una ventana de filas filtrada por offset, aunque el hardware transmita toda la DMEM completa.
- `Clear DMEM` y reset independiente siguen pendientes de RTL/comando dedicado.
