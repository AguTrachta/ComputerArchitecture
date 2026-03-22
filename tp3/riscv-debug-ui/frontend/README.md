# Frontend RISC-V Debug UI

Frontend en Vanilla JS/CSS/HTML servido por FastAPI desde la raiz del backend.

## Estado actual

El frontend ya no funciona con eventos emulados.

Ahora consume:

- REST para conexion, programacion, control y dumps
- WebSocket para `uart_tx`, `uart_rx`, `backend_state`, `regs_dump`, `pipeline_dump`, `mem_dump`, `warning` y `error`
- `GET /status` para hidratar el estado inicial de la UI

## Componentes

- `app.js`: inicializa tabs, sincroniza indicadores superiores y carga el estado inicial.
- `api.js`: cliente REST real.
- `ws.js`: cliente WebSocket real con reconexion basica.
- `state.js`: estado reactivo compartido para conexion, CPU y capacidades.
- `components/editor.js`: validacion, ensamblado y ejemplo ASM valido.
- `components/controls.js`: acciones reales contra la API y bloqueo de botones segun estado/capacidades.
- `components/registers.js`: render de 32 registros usando solo nombres `x0..x31` en la tabla.
- `components/pipeline.js`: render del dump real de latches en `Global`, `IF/ID`, `ID/EX`, `EX/MEM` y `MEM/WB`.
- `components/memory.js`: render de una ventana del dump real de memoria de datos.
- `components/console.js`: log visual de API, TX, RX, warnings y errores.

## Nota

`dump_pipeline` y `dump_memory` ya consumen payload real del RTL. La vista de memoria muestra una ventana filtrada por offset aunque el hardware transmita la DMEM completa.
