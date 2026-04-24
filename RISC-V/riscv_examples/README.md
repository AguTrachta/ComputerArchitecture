# Ejemplos RISC-V para probar el frontend/debugger

Estos archivos `.s` están pensados para validar partes puntuales del pipeline y del frontend.
La idea es cargar un programa, ejecutarlo con **Run** o **Step**, y mirar qué ocurre en las distintas pestañas.

## 1. `01_addi_store_basic.s`
Prueba básica de escritura de registros y luego escritura en memoria.

### Qué hace
- Carga en registros:
  - `x1 = 11`
  - `x2 = 22`
  - `x3 = 33`
  - `x4 = 44`
- Luego guarda esos valores en memoria en:
  - `mem[0] = 11`
  - `mem[4] = 22`
  - `mem[8] = 33`
  - `mem[12] = 44`

### Qué deberías observar
**Pestaña/editor de código**
- El programa debe verse corto y simple, útil para validar el flujo completo.

**Pestaña de consola/logs**
- Debe cargar sin errores y ejecutarse normalmente.

**Pestaña de registros**
- Al final deben quedar: `x1=11`, `x2=22`, `x3=33`, `x4=44`.

**Pestaña de memoria**
- Deben aparecer esos cuatro valores en las primeras cuatro palabras.

**Pestaña de pipeline**
- Deberías ver instrucciones `addi` al principio y luego `sw` avanzando por las etapas.

---

## 2. `02_forwarding_alu.s`
Prueba de dependencias entre instrucciones ALU consecutivas.

### Qué hace
- Genera una cadena de operaciones donde cada instrucción usa el resultado de la anterior.
- Valores esperados:
  - `x3 = 12`
  - `x4 = 7`
  - `x5 = 7`
  - `x6 = 7`
  - `x7 = 0`

### Qué deberías observar
**Pestaña de registros**
- Los valores finales anteriores deben coincidir exactamente.

**Pestaña de pipeline**
- Esta es la más importante en este ejemplo.
- Si el forwarding está bien, las instrucciones deberían ejecutarse sin que aparezcan resultados incorrectos.
- También es útil ver señales o campos de forwarding si tu frontend los muestra.

**Pestaña de consola/logs**
- No deberían aparecer errores ni resultados corridos.

---

## 3. `03_load_use_stall.s`
Prueba clásica de hazard de tipo **load-use**.

### Qué hace
- Guarda `99` en memoria.
- Lo carga con `lw` a `x2`.
- Inmediatamente después usa `x2` en un `add`.
- Resultado esperado:
  - `x2 = 99`
  - `x3 = 198`
  - `x4 = 199`

### Qué deberías observar
**Pestaña de registros**
- Los resultados finales deben ser correctos.

**Pestaña de pipeline**
- Si tu CPU implementa detección de hazard load-use, debería aparecer un **stall** o burbuja.
- Este ejemplo sirve justamente para validar eso.

**Pestaña de memoria**
- En `mem[0]` debe quedar `99`.

**Pestaña de consola/logs**
- La ejecución debería terminar normal, aunque internamente tome un ciclo extra por el stall.

---

## 4. `04_branch_flush.s`
Prueba de branch tomado y anulación de instrucciones incorrectas.

### Qué hace
- Compara `x1` y `x2`, ambos con valor `10`.
- El `beq` debe tomarse.
- Las instrucciones siguientes (`addi x3...` y `addi x4...`) no deberían afectar el estado final.
- Resultado esperado:
  - `x1 = 10`
  - `x2 = 10`
  - `x3 = 0`
  - `x4 = 0`
  - `x5 = 55`

### Qué deberías observar
**Pestaña de registros**
- `x3` y `x4` deben quedar sin escribir.
- `x5` sí debe tomar el valor `55`.

**Pestaña de pipeline**
- Este es el lugar ideal para ver el **flush**.
- Las instrucciones posteriores al branch, si entraron parcialmente al pipeline, deberían invalidarse.

**Pestaña de consola/logs**
- La ejecución debe seguir normalmente, pero con redirección del PC.

---

## 5. `05_memory_lw_sw_sequence.s`
Prueba sencilla de escritura y lectura secuencial de memoria.

### Qué hace
- Guarda 4 valores en memoria.
- Luego los vuelve a leer en otros registros.
- Resultado esperado:
  - `x5 = 1`
  - `x6 = 2`
  - `x7 = 3`
  - `x8 = 4`

### Qué deberías observar
**Pestaña de registros**
- Los registros cargados por `lw` deben coincidir con lo escrito previamente.

**Pestaña de memoria**
- Deben verse las posiciones iniciales con `1, 2, 3, 4`.

**Pestaña de pipeline**
- Deberías ver primero los `sw` y luego los `lw` atravesando el pipeline.

---

# Recomendación de uso
Un orden razonable para probar todo sería:

1. `01_addi_store_basic.s`  
   Para validar que carga, ejecuta y escribe bien.
2. `05_memory_lw_sw_sequence.s`  
   Para validar memoria completa: write + read.
3. `02_forwarding_alu.s`  
   Para validar forwarding entre instrucciones ALU.
4. `03_load_use_stall.s`  
   Para validar stalls por dependencia con `lw`.
5. `04_branch_flush.s`  
   Para validar flush por branch tomado.

# Resumen rápido
- **Registros**: mirá valores finales esperados.
- **Memoria**: confirmá stores y loads.
- **Pipeline**: mirá avance por etapas, stalls, flushes y forwarding.
- **Consola/logs**: verificá que no haya timeouts, respuestas truncadas o errores UART/backend.
