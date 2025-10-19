# UART on Basys3 (Artix-7)

## Overview

This project implements a **full-duplex UART** on the **Basys3** FPGA board (Xilinx Artix-7), extended with a small command-driven processing pipeline:

```
UART RX → FIFO RX → rv_interface (assemble 32-bit instr)
         → rv_decoder (R/I format, fields, alu_op)
         → regfile & ALU → (write-back) → FIFO TX → UART TX
```

The **ALU** module is **reused from the previous project** and supports basic arithmetic/logic ops. The new `rv_interface` + `rv_decoder` + `regfile` layer turns byte streams into **32-bit instructions** (LSB-first), enabling simple R-type (reg–reg) and I-type (reg–imm) operations over UART.

---

## Features

* **16× oversampling UART** (parametrizable baud rate).
* **Dual FIFOs** (RX/TX) to decouple timing safely.
* **Command protocol** over UART:

  * 4 bytes → **32-bit instruction** (LSB-first).
  * `rv_decoder` classifies **R-type** (`opcode = 0x33`) and **I-type** (`opcode = 0x13`), extracts `rd`, `rs1`, `rs2` / `imm`, and selects `alu_op`.
* **Register file (regfile)**:

  * 8-bit datapath (adjust as needed), read `rs1`/`rs2`, write-back to `rd` (guarded: `rd != 0`).
* **ALU** (from previous project):

  * ADD, SUB, AND, OR, XOR, (extendable).
* **Clean FSM** in `rv_interface`:

  * `S_IDLE → S_I0 → S_I1 → S_I2 → S_I3 → S_EX → S_WB → S_TX`.

---

## Hardware Mapping (Basys3)

* **Clock**: 100 MHz onboard oscillator → `i_clk`.
* **UART**: Using 3V3 TTL pins, `rx` → JB1 board pin, `tx` → JB2 board pin
* **Reset**: Single active-high/low. Map to U18 button (`BTNC`).

---

## Usage Instructions

### 1) Prepare the project in Vivado

* Create a new Vivado project for Basys3.
* Add HDL sources:

  * `baud_gen.v`, `uart_rx.v`, `uart_tx.v`, `fifo.v`
  * **Interface stack**: `rv_interface.v`, `rv_decoder.v`, `regfile.v`
  * **ALU** (reused from previous project)
  * `top.v`
* Add constraints: Basys3 **Master XDC**.

### 2) Build the bitstream

* Run **Synthesis** → **Implementation** → **Generate Bitstream**.

### 3) Program the board

* Connect Basys3 via USB, power on.
* Vivado **Hardware Manager** → Open target → Program device with the generated `.bit`.

### 4) Open a serial terminal

* Connect to **USB-UART** (COMx/ttyUSBx).
* Typical UART settings (adjust if you changed params):

  * **Baud**: 9600
  * **Data**: 8 bits
  * **Parity**: None
  * **Stop**: 1
* Send **binary** packets (4 bytes LSB-first) as per the instruction format.

---

## Protocol (Instruction Format)

* **Transport:** 4 bytes over UART (LSB-first) → `instr[31:0]`.
* **Decoder:**

  * **R-type** (reg–reg): `opcode = 0x33`

    * uses `funct3`, `funct7`, fields: `rd`, `rs1`, `rs2`.
  * **I-type** (reg–imm): `opcode = 0x13`

    * uses `funct3`, fields: `rd`, `rs1`, `imm[11:0]` (signed).
* **ALU op** is selected from `funct3/funct7` (R) or `funct3` (I).
* **Write-back:** if (R or I) and `rd != 0`, the result is written to `rd`.
* **TX Response:** interface pushes 1 byte (typically `result[7:0]`) to FIFO TX (configurable).

---

## Example Walkthrough

**Example A — R-type ADD (`rd = rs1 + rs2`):**

1. Host assembles a 32-bit R-type instruction with `opcode=0x33`, `funct3=000`, `funct7=0000000`, and field indexes for `rd`, `rs1`, `rs2`.
2. Send 4 bytes **LSB-first** over UART.
3. FPGA: `rv_interface` collects bytes (`S_I0..S_I3`), `rv_decoder` flags **R-type**, extracts fields, selects **ADD**.
4. `regfile` outputs `rs1`, `rs2` → **ALU** computes result.
5. If `rd != 0`: **write-back**.
6. Interface enqueues `result[7:0]` in **FIFO TX** → UART TX → host sees the reply.

**Example B — I-type ADDI (`rd = rs1 + imm`):**

1. Host encodes `opcode=0x13`, `funct3=000`, fields `rd`, `rs1`, `imm[11:0]`.
2. Transmit 4 bytes LSB-first.
3. Decoder flags **I-type**, extracts fields, selects **ADD**.
4. ALU uses `rs1` and **sign-extended** `imm` (truncated/extended to datapath).
5. Write-back to `rd` (if `rd != 0`) and optional TX reply.

---

## Project Structure

```Python
ComputerArchitecture/UART/
├── UART.srcs/
|   ├── sources_1/new/
│   │   ├── top.v
│   │   ├── baud_gen.v
│   │   ├── uart_rx.v
│   │   ├── uart_tx.v
│   │   ├── fifo.v
│   │   ├── rv_interface.v
│   │   ├── rv_decoder.v
│   │   └── regfile.v
│   ├── sim_1/new/
│   │   └── tb_top.v
│   └── constr_1/new/
│       └── basys3.xdcreset
├── doc/
│   └── documentation.pdf
└── README.md
```

---

## Notes

* **Baud rate & timing:** default examples assume **9600 8-N-1** with 16× oversampling. Adjust `BAUD_RATE` and divisors in `baud_gen.v` if needed.
* **FSM robustness:** consider an upgrade adding a **timeout** in `S_I0..S_I3` to discard incomplete instructions; optionally add a simple **checksum**.
* **Result width:** if you need multi-byte results, extend `S_TX` into a small TX-sequence (e.g., send 2–4 bytes) and document the reply format.
* **Register x0:** writes to `rd=0` are ignored to preserve a hard-wired zero register.
