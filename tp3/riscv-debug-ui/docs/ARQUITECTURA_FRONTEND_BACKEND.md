
# Arquitectura de software para la interfaz de depuración del procesador RISC-V

## 1. Objetivo

Diseñar una aplicación de escritorio/web local para interactuar con el procesador RISC-V implementado en FPGA mediante UART, permitiendo:

- cargar programas en memoria de instrucciones,
- ejecutar en modo continuo o paso a paso,
- detener la ejecución,
- solicitar dumps del estado interno,
- visualizar registros, memoria y estado del pipeline,
- mostrar información en vivo a medida que se reciben datos desde la FPGA.

La aplicación se dividirá en dos grandes bloques:

- **Frontend**: interfaz visual para el usuario.
- **Backend**: lógica de negocio, comunicación UART, parsing de respuestas y publicación de eventos en tiempo real.

---

## 2. Alcance de esta etapa

En esta etapa se define la arquitectura completa de la solución de software, contemplando:

- uso de **Python** como lenguaje principal del backend,
- uso de **uv** como gestor de entorno y dependencias,
- uso de **WebSockets** para actualización en tiempo real,
- separación clara entre frontend y backend,
- preparación de la interfaz para mostrar información del pipeline en vivo,
- validación de los límites reales impuestos por el hardware actual.

No se contempla todavía en esta etapa:

- implementación del compilador de C,
- definición final del wireframe visual,
- ampliaciones RTL pendientes para dumps avanzados.

---

## 3. Tecnologías elegidas

## Backend
- **Python**
- **uv** para gestión del proyecto y dependencias
- **FastAPI** como framework HTTP
- **WebSocket** para streaming de eventos al frontend
- **pyserial** para comunicación UART con la FPGA
- **pydantic** para validación de estructuras de datos
- **asyncio** para concurrencia y tareas no bloqueantes

## Frontend
- **HTML**
- **CSS**
- **JavaScript**
- Comunicación con el backend mediante:
  - **REST** para operaciones puntuales
  - **WebSocket** para eventos en tiempo real

---

## 4. Motivación de la arquitectura elegida

La aplicación necesita cumplir simultáneamente con varios objetivos:

- manejar un puerto serial físico,
- procesar comandos y respuestas de un protocolo UART,
- realizar validaciones previas de programación,
- mantener una interfaz clara y reactiva,
- transmitir al frontend cambios de estado en tiempo real,
- permitir extender la solución en el futuro con nuevas capacidades.

Por este motivo se adopta una arquitectura desacoplada:

- el **frontend** solo se encarga de la interacción visual,
- el **backend** concentra toda la lógica de protocolo, estados y comunicación con la FPGA.

Esta separación evita:
- lógica serial en el navegador,
- dependencia del hardware en la capa visual,
- acoplamiento entre interfaz y protocolo,
- dificultad de mantenimiento.

---

## 5. Arquitectura general

```text
┌─────────────────────────────────────────────────────┐
│                     Frontend                        │
│        HTML + CSS + JavaScript + WebSocket         │
│                                                     │
│  - Editor ASM                                       │
│  - Botones de control                               │
│  - Vistas de registros/memoria/pipeline             │
│  - Consola/log                                      │
└─────────────────────────────────────────────────────┘
                     │
                     │ REST + WebSocket
                     ▼
┌─────────────────────────────────────────────────────┐
│                     Backend                         │
│      Python + FastAPI + pyserial + asyncio         │
│                                                     │
│  - API HTTP                                         │
│  - Servidor WebSocket                               │
│  - UART manager                                     │
│  - Protocol parser                                  │
│  - Session state manager                            │
│  - Program loader / assembler                       │
└─────────────────────────────────────────────────────┘
                     │
                     │ UART
                     ▼
┌─────────────────────────────────────────────────────┐
│                      FPGA                           │
│       Debug Unit + UART RX/TX + CPU Pipeline       │
└─────────────────────────────────────────────────────┘
```

---

## 6. Responsabilidades de cada capa

## 6.1 Frontend

El frontend debe:

* permitir seleccionar puerto y baud rate,
* mostrar el estado de conexión,
* permitir cargar o escribir un programa en ASM,
* mostrar el resultado de la traducción a HEX,
* habilitar programación de memoria de instrucciones,
* permitir control de ejecución:

  * run,
  * stop,
  * step,
* solicitar dumps,
* mostrar registros,
* mostrar memoria,
* mostrar estado del pipeline,
* mostrar logs y errores,
* reaccionar en tiempo real a eventos enviados por el backend.

El frontend **no debe**:

* acceder directamente al puerto serial,
* conocer detalles internos del framing UART,
* manejar timeouts del protocolo,
* codificar o parsear respuestas crudas.

---

## 6.2 Backend

El backend debe:

* descubrir y abrir puertos seriales,
* configurar la UART correctamente,
* enviar comandos a la Debug Unit,
* recibir respuestas,
* parsear headers, payloads y finales de trama,
* detectar errores de protocolo,
* aplicar timeouts,
* serializar la información para el frontend,
* mantener estado interno consistente,
* publicar eventos por WebSocket,
* validar programas antes de programar la FPGA,
* preparar el sistema para futuras extensiones.

---

## 7. Restricciones del hardware actual

De acuerdo con la implementación actual del sistema, el software debe asumir los siguientes límites reales:

## 7.1 UART

* UART de 8 bits
* formato 8N1
* baud rate actualmente fijado por hardware
* valor actual esperado: **9600 baud**

Esto implica que el selector de baud rate en la interfaz debe considerarse una configuración local compatible con la bitstream cargada. No debe asumirse como negociable dinámicamente salvo que el RTL lo soporte explícitamente.

## 7.2 Memoria de instrucciones

* direccionamiento por palabra
* `ADDR_W = 10`
* capacidad: **1024 instrucciones**
* ancho de instrucción: **32 bits**
* tamaño total: **4096 bytes**

## 7.3 Memoria de datos

* `DEPTH_BYTES = 4096`
* tamaño total: **4 KB**
* direccionamiento válido por byte: `0x00000000` a `0x00000FFF`
* direccionamiento válido por word: `0x00000000` a `0x00000FFC`

## 7.4 Observabilidad actual

La arquitectura de software debe distinguir entre:

### Funcionalidades realmente operativas hoy

* programación de memoria de instrucciones,
* ejecución continua,
* ejecución paso a paso,
* stop,
* dump de registros.

### Funcionalidades preparadas en interfaz pero dependientes de RTL

* dump completo de latches del pipeline,
* dump real de memoria de datos,
* clear de memoria de datos,
* reset completo del sistema por comando independiente.

---

## 8. Estilo de comunicación entre frontend y backend

Se utilizarán dos mecanismos complementarios.

## 8.1 REST

Se usará para operaciones discretas y controladas, por ejemplo:

* listar puertos,
* conectar,
* desconectar,
* programar,
* run,
* stop,
* step,
* solicitar dump,
* validar un programa,
* traducir ASM a HEX.

## 8.2 WebSocket

Se usará para eventos en tiempo real, por ejemplo:

* cambio de estado del sistema,
* progreso de programación,
* logs UART TX/RX,
* llegada de dumps,
* cambios en registros,
* actualización de vistas del pipeline,
* eventos de error o timeout.

El backend actuará como publicador central de eventos, y el frontend se suscribirá a ellos para actualizar la UI sin polling.

---

## 9. Modelo de estados del sistema

El backend debe mantener un estado de sesión consistente. Como mínimo:

* `DISCONNECTED`
* `CONNECTED`
* `IDLE`
* `PROGRAMMING`
* `PROGRAMMED`
* `RUNNING`
* `STEPPING`
* `DUMPING`
* `ERROR`

### Reglas generales

* no se puede programar si no hay conexión,
* no se puede correr si no hay programa cargado,
* no se debe enviar `STOP` si el backend no considera que la CPU está corriendo,
* durante `PROGRAMMING` deben bloquearse comandos de ejecución,
* durante `RUNNING` deben bloquearse acciones destructivas como reprogramar o limpiar memorias,
* ante timeout o respuesta inválida, el backend debe pasar a `ERROR` y notificar por WebSocket.

---

## 10. Módulos internos del backend

## 10.1 SerialManager

Responsabilidad:

* listar puertos,
* abrir/cerrar puerto,
* escribir bytes,
* leer bytes,
* configurar baud rate,
* manejar timeouts de bajo nivel.

Funciones típicas:

* `list_ports()`
* `connect(port, baudrate)`
* `disconnect()`
* `write_bytes(data)`
* `read_exact(n, timeout)`
* `read_until(...)`

---

## 10.2 ProtocolManager

Responsabilidad:

* encapsular el protocolo UART de la Debug Unit,
* enviar comandos de alto nivel,
* parsear respuestas,
* validar secuencias esperadas,
* detectar inconsistencias.

Funciones típicas:

* `clear_imem()`
* `program(words)`
* `run()`
* `stop()`
* `step()`
* `dump_regs()`
* `dump_latches()`
* `dump_mem()`

Debe transformar:

* bytes crudos UART
  en
* objetos semánticos comprensibles para el resto del backend.

---

## 10.3 SessionManager

Responsabilidad:

* mantener el estado actual del sistema,
* almacenar último dump recibido,
* llevar contadores de steps y ejecuciones,
* almacenar errores,
* exponer información al frontend.

Debe contener, como mínimo:

* estado actual,
* puerto conectado,
* baud rate,
* programa actual,
* último dump de registros,
* último dump de pipeline,
* último dump de memoria,
* historial de logs,
* flags de capacidad RTL.

---

## 10.4 ProgramManager

Responsabilidad:

* recibir ASM desde el frontend,
* validarlo,
* traducirlo a HEX,
* controlar el tamaño máximo,
* preparar palabras de 32 bits para programación.

Entradas:

* texto ASM

Salidas:

* lista de instrucciones normalizadas,
* lista de words hex,
* tamaño total en instrucciones y bytes,
* errores de parseo o validación.

---

## 10.5 EventBus / WebSocketHub

Responsabilidad:

* mantener clientes WebSocket conectados,
* publicar eventos,
* segmentar por tipo de evento si fuese necesario.

Debe permitir eventos como:

* `connection_status`
* `backend_state`
* `uart_tx`
* `uart_rx`
* `program_progress`
* `regs_dump`
* `pipeline_dump`
* `mem_dump`
* `warning`
* `error`

---

## 11. Estructura sugerida del proyecto

```text
riscv-debug-ui/
├── pyproject.toml
├── uv.lock
├── README.md
├── app/
│   ├── main.py
│   ├── api/
│   │   ├── routes_connection.py
│   │   ├── routes_program.py
│   │   ├── routes_control.py
│   │   ├── routes_dump.py
│   │   └── routes_status.py
│   ├── core/
│   │   ├── config.py
│   │   ├── state.py
│   │   └── events.py
│   ├── serial/
│   │   ├── serial_manager.py
│   │   └── protocol_manager.py
│   ├── program/
│   │   ├── assembler.py
│   │   ├── validator.py
│   │   └── models.py
│   ├── ws/
│   │   └── websocket_manager.py
│   └── models/
│       ├── requests.py
│       ├── responses.py
│       └── dumps.py
├── frontend/
│   ├── index.html
│   ├── styles.css
│   ├── app.js
│   ├── api.js
│   ├── ws.js
│   ├── state.js
│   └── components/
│       ├── editor.js
│       ├── controls.js
│       ├── registers.js
│       ├── memory.js
│       ├── pipeline.js
│       └── console.js
└── docs/
    └── ARQUITECTURA_FRONTEND_BACKEND.md
```

---

## 12. Gestión del proyecto con uv

El proyecto Python se administrará con `uv`.

## Objetivos del uso de uv

* manejo reproducible de dependencias,
* instalación rápida,
* entorno simple,
* lockfile consistente.

## Dependencias esperadas

* `fastapi`
* `uvicorn`
* `pyserial`
* `pydantic`
* `python-multipart` si fuera necesario
* librerías auxiliares de testing o linting según se definan más adelante

---

## 13. API HTTP propuesta

## 13.1 Conexión

### `GET /ports`

Devuelve la lista de puertos seriales disponibles.

### `POST /connect`

Conecta a un puerto dado con un baud rate determinado.

### `POST /disconnect`

Cierra la conexión serial activa.

---

## 13.2 Programa

### `POST /program/validate`

Valida ASM y devuelve:

* errores,
* warnings,
* cantidad de instrucciones,
* ocupación de IMEM.

### `POST /program/assemble`

Traduce ASM a HEX.

### `POST /program/load`

Programa la memoria de instrucciones en FPGA.

### `POST /program/clear-imem`

Limpia la memoria de instrucciones.

---

## 13.3 Control de ejecución

### `POST /control/run`

Inicia ejecución continua.

### `POST /control/stop`

Solicita detener ejecución.

### `POST /control/step`

Ejecuta un paso.

---

## 13.4 Dumps

### `POST /dump/regs`

Solicita dump de registros.

### `POST /dump/pipeline`

Solicita dump de latches/pipeline.

### `POST /dump/memory`

Solicita dump de memoria.

---

## 13.5 Estado

### `GET /status`

Devuelve el estado consolidado de la sesión:

* conexión,
* puerto,
* baud,
* estado CPU,
* capacidades disponibles,
* últimos timestamps relevantes.

---

## 14. Eventos WebSocket propuestos

Cada evento enviado al frontend debería incluir al menos:

* `type`
* `timestamp`
* `payload`

## 14.1 Ejemplos de eventos

### Estado de conexión

```json
{
  "type": "connection_status",
  "timestamp": "2026-03-20T18:00:00",
  "payload": {
    "connected": true,
    "port": "COM5",
    "baudrate": 9600
  }
}
```

### Estado interno del backend

```json
{
  "type": "backend_state",
  "timestamp": "2026-03-20T18:00:01",
  "payload": {
    "state": "RUNNING"
  }
}
```

### Log UART TX

```json
{
  "type": "uart_tx",
  "timestamp": "2026-03-20T18:00:02",
  "payload": {
    "bytes_hex": ["20"],
    "text": "CMD_RUN"
  }
}
```

### Log UART RX

```json
{
  "type": "uart_rx",
  "timestamp": "2026-03-20T18:00:02",
  "payload": {
    "bytes_hex": ["C4"],
    "text": "RESP_RUN_END"
  }
}
```

### Dump de registros

```json
{
  "type": "regs_dump",
  "timestamp": "2026-03-20T18:00:03",
  "payload": {
    "registers": [
      {"name": "x0", "alias": "zero", "hex": "0x00000000", "dec": 0},
      {"name": "x1", "alias": "ra",   "hex": "0x00000005", "dec": 5}
    ]
  }
}
```

### Dump de pipeline

```json
{
  "type": "pipeline_dump",
  "timestamp": "2026-03-20T18:00:04",
  "payload": {
    "if_id": {},
    "id_ex": {},
    "ex_mem": {},
    "mem_wb": {},
    "valid": false,
    "source": "placeholder_until_rtl_ready"
  }
}
```

### Error

```json
{
  "type": "error",
  "timestamp": "2026-03-20T18:00:05",
  "payload": {
    "code": "UART_TIMEOUT",
    "message": "No se recibió respuesta dentro del tiempo esperado"
  }
}
```

---

## 15. Flujo de programación de un programa

## Flujo lógico

1. El usuario escribe o carga ASM.
2. El frontend envía el texto al backend.
3. El backend valida el programa.
4. El backend traduce ASM a palabras de 32 bits.
5. Se verifica que no supere el límite de 1024 instrucciones.
6. El backend limpia IMEM si corresponde.
7. El backend inicia la secuencia de programación por UART.
8. El backend publica progreso por WebSocket.
9. Si todo es correcto, actualiza el estado a `PROGRAMMED`.
10. El frontend muestra el resultado.

## Observaciones

* el frontend no debe construir el payload UART,
* la serialización de words debe quedar encapsulada en el backend,
* el orden de bytes de cada instrucción debe definirse en un único lugar del sistema.

---

## 16. Flujo de ejecución en modo continuo

1. El usuario presiona `Run`.
2. El frontend llama al endpoint correspondiente.
3. El backend verifica estado válido.
4. El backend envía comando UART.
5. El backend pasa a `RUNNING`.
6. El backend publica evento de cambio de estado.
7. Mientras haya eventos relevantes, los retransmite al frontend.
8. Al finalizar, actualiza estado a `IDLE` o `PROGRAMMED` según corresponda.
9. El frontend refleja el fin de ejecución.

---

## 17. Flujo de ejecución paso a paso

1. El usuario presiona `Step`.
2. El frontend llama al backend.
3. El backend valida que el sistema esté en un estado apto.
4. El backend envía el comando `STEP`.
5. El backend espera la confirmación correspondiente.
6. Se incrementa el contador interno de pasos.
7. Se solicita automáticamente un refresh del estado observable.
8. El backend publica por WebSocket:

   * nuevo estado,
   * dump de registros,
   * dump de pipeline si está disponible,
   * logs UART asociados.

Este modo es especialmente importante para la visualización didáctica del pipeline.

---

## 18. Visualización en vivo del pipeline

Uno de los objetivos principales de esta arquitectura es poder mostrar datos en vivo del pipeline.

## Principio general

El frontend no debe hacer polling continuo de tablas ni depender de refrescos manuales. En cambio:

* el backend obtiene la información observable del hardware,
* la normaliza,
* la publica por WebSocket,
* el frontend actualiza inmediatamente las vistas.

## Beneficios

* menor latencia visual,
* mejor experiencia de uso,
* mayor claridad en demo y depuración,
* capacidad de resaltar cambios entre ciclos.

## Consideración importante

La riqueza real de esta visualización dependerá de qué información exponga finalmente el RTL. La arquitectura de software debe quedar preparada desde ahora para:

* `IF/ID`
* `ID/EX`
* `EX/MEM`
* `MEM/WB`
* señales de control
* PC
* instrucción
* operandos
* resultados intermedios
* flags de stall/flush

Aunque al comienzo algunos de esos campos lleguen vacíos o en modo placeholder.

---

## 19. Consideraciones de UX derivadas de la arquitectura

El sistema visual debe comportarse de forma consistente con el estado interno del backend.

## Reglas sugeridas

* deshabilitar `Run` si no hay programa cargado,
* deshabilitar `Program` durante `RUNNING`,
* deshabilitar `Stop` si no está corriendo,
* mostrar indicadores visuales claros de:

  * conexión,
  * actividad UART,
  * estado de CPU,
  * errores,
  * operaciones pendientes,
* resaltar registros que cambiaron entre dumps,
* mostrar warnings si una funcionalidad depende de RTL aún no implementado.

---

## 20. Errores y manejo de fallos

El backend debe contemplar como mínimo:

* puerto no encontrado,
* puerto ocupado,
* desconexión inesperada,
* timeout UART,
* respuesta inválida,
* longitud de dump incorrecta,
* programa demasiado grande,
* error de parseo de ASM,
* comando no permitido en el estado actual.

## Política recomendada

* no ocultar errores,
* conservar historial de eventos,
* enviar errores por WebSocket,
* devolver también respuestas HTTP claras al frontend.

---

## 21. Capacidades y límites declarados por software

El backend debería mantener una estructura de capacidades, por ejemplo:

```json
{
  "can_clear_imem": true,
  "can_clear_dmem": false,
  "can_dump_regs": true,
  "can_dump_pipeline": true,
  "can_dump_pipeline_full_payload": false,
  "can_dump_memory_full_payload": false,
  "can_reset_exec_independent": false
}
```

Esto permite que el frontend:

* muestre botones deshabilitados cuando corresponda,
* explique al usuario qué depende de RTL,
* mantenga una interfaz honesta y coherente.

---

## 22. Criterios de diseño para extensibilidad

La arquitectura debe facilitar incorporar más adelante:

* soporte para C,
* nuevas instrucciones,
* nuevos comandos UART,
* más dumps específicos,
* lectura parcial de memoria,
* autorefresco configurable,
* grabación de sesiones,
* exportación de logs,
* comparación entre dumps.

Esto justifica mantener bien desacoplados:

* parser ASM,
* protocolo UART,
* almacenamiento de estado,
* rendering visual.

---

## 23. Resultado esperado de esta etapa

Al finalizar esta etapa, debería existir una base de software capaz de:

* conectarse a la FPGA por UART,
* cargar programas en memoria de instrucciones,
* controlar la ejecución,
* obtener y mostrar dumps disponibles,
* reflejar cambios en tiempo real por WebSocket,
* preparar la interfaz para observar el pipeline en vivo,
* servir de base firme para el wireframe visual y futuras ampliaciones del RTL.

---

## 24. Próximos pasos

Los siguientes pasos del proyecto serán:

1. revisar qué falta agregar o completar en el RTL para soportar toda la observabilidad deseada,
2. definir el wireframe exacto de la interfaz,
3. aterrizar los modelos de datos finales para registros, memoria y pipeline,
4. implementar la base del backend en Python con uv y WebSockets,
5. desarrollar el frontend visual sobre esa API.
