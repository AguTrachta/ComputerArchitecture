# RISC-V Debug UI Frontend MVP

Este es el frontend MVP (Vanilla HTML/CSS/JS) diseñado según la arquitectura descrita en `ARQUITECTURA_FRONTEND_BACKEND.md`.

## 📁 Estructura de Archivos

* `index.html`: La estructura principal del DOM (wireframe layout). Incluye las columnas: **PROGRAMA**, **CONTROL** y **OBSERVABILIDAD**.
* `styles.css`: Define el estilo visual. Tiene variables nativas para *Dark Mode*, fuentes modernas y efectos *Glassmorphism*. No requiere Tailwind ni frameworks externos.
* `state.js`: El cerebro reactivo del MVP. Mantiene el estado local (Conexión, Estado de CPU) e implementa el patrón Observer.
* `api.js`: Simula llamadas asincrónicas a los endpoints REST del backend. Los botones interactúan con estos mocks de forma transparente aportando validación visual del flujo.
* `ws.js`: Módulo mock de WebSocket para inyectar eventos de backend directamente al frontend.
* `app.js`: El punto de entrada principal. Configura Listeners, los Tabs y actualiza la Barra Superior de la UI.
* `components/`:
  * `editor.js`: Código del panel de texto (ASM), Validación y Traducción (y muestra de HEX colapsable generado).
  * `controls.js`: Acciones de Conexión, Programación FPGA, Ejecución (`Run`, `Stop`, `Step`) y dumps. **Probalo dándole a 'Step' o 'Run' para ver la propagación.**
  * `registers.js`: Actualiza la tabla de registros en el Tab `Regs`.
  * `memory.js`: Muestra y pide los bytes en el Tab `Mem` (mediante mock payload).
  * `pipeline.js`: Renders dinámicos del pipeline, colapsables nativos (`<details>`). Respeta los estados iniciales "abiertos por defecto" (`Global`, `IF/ID`, `ID/EX`, `EX/MEM`, `MEM/WB`).
  * `console.js`: Agrega logs locales.

## 🚀 Cómo Testear Localmente

Al no utilizar bundlers como Webpack o Vite, podés servir este directorio de forma rápida creando un simple servidor HTTP en cualquier terminal o en VS Code.

### Opcion 1: Usando Python (Recomendado)
Abre PowerShell o tu terminal dentro del directorio actual (`frontend`) y ejecuta:
```bash
python -m http.server 8000
```
Luego navegá a `http://localhost:8000/`.

### Opción 2: Usando VS Code
Si tenés instalada la extensión **Live Server**, simplemente hace click derecho sobre `index.html` y selecciona **"Open with Live Server"**.

## 📝 Probando la Interfaz (Mocks)
Los botones ya tienen lógica emulada (delays) que actualiza el estado gráfico:
1. Haz clic en **Conectar** (simulará una conexión demorada).
2. Agrega código ASM en el Editor y clickeá **Traducir** (observá el panel HEX colapsable).
3. Haz clic en **Programar FPGA** (verás el estado pasar a PROGRAMMING).
4. Dale a la pestaña de Observabilidad **Pipeline**, y haz clic en **Step ⏭** bajo *Control*.
5. Verás cómo llegan `Eventos WebSocket` emulados y actualizan automáticamente el flujo del pipeline (Regs y Pipeline se actualizan dinámicamente).
