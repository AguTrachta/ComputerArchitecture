# ALU on Basys3 (Artix-7)

## Overview

This project implements a **Arithmetic Logic Unit (ALU)** on the Basys 3 FPGA board.
The ALU supports basic arithmetic and logic operations using two signed 8-bit operands and a 6-bit operation code (opcode).
Inputs are provided via the on-board switches and push buttons, and results are displayed on the LEDs.

The project consists of:

* `alu.v`: the ALU module (parametric, 8-bit data / 6-bit opcodes).
* `top.v`: the top-level module connecting ALU with Basys3 hardware (switches, buttons, LEDs).
* `top_alu.xdc`: constraint file mapping FPGA pins to board peripherals.
* `tb_top_alu.v`: testbench for simulation.

---

## Features

* **Operands**: two signed 8-bit registers (`A`, `B`).
* **Operation code**: 6-bit, selecting which ALU function to perform.
* **Operations implemented**:

  * `ADD` (100000): addition
  * `SUB` (100010): subtraction
  * `AND` (100100): bitwise AND
  * `OR`  (100101): bitwise OR
  * `XOR` (100110): bitwise XOR
  * `SRA` (000011): arithmetic right shift
  * `SRL` (000010): logical right shift
  * `NOR` (100111): bitwise NOR
* **Reset**: clears both operands and opcode.
* **Display**:

  * `LED[7:0]`: current switch values (live mirror).
  * `LED[15:8]`: ALU result (updates after loading operands and opcode).

---

## Hardware Mapping (Basys3)

* **Clock**: 100 MHz onboard oscillator (`i_clk`).
* **Switches**:

  * `SW[7:0]` → `i_sw_data[7:0]` (used to input values or opcode).
* **Push Buttons**:

  * `BTN Left` → load `A` (latches `SW[7:0]` into operand A).
  * `BTN Right` → load `B` (latches `SW[7:0]` into operand B).
  * `BTN Center` → load `OP` (latches `SW[5:0]` into opcode).
  * `BTN Up` → reset (clears A, B, OP).
* **LEDs**:

  * `LED[7:0]` → shows current `SW[7:0]`.
  * `LED[15:8]` → shows ALU result.

---

## Usage Instructions

1. **Prepare the project in Vivado**:

   * Create a new RTL project targeting **Basys3 (XC7A35T)**.
   * Add `alu.v` and `top.v` as design sources.
   * Add `top_alu.xdc` as the constraint file.
   * Add `tb_top_alu.v` as simulation source (optional).
   * Set `top.v` as the top module.

2. **Build the bitstream**:

   * Run **Synthesis** → **Implementation** → **Generate Bitstream**.

3. **Program the board**:

   * Connect the Basys3 via USB and power it on.
   * Open **Hardware Manager** in Vivado, connect to the board, and program with the generated `.bit` file.

4. **Test the design**:

   * Use `SW[7:0]` to set values.
   * Press **BTN Left** to load operand A.
   * Update Switch values.
   * Press **BTN Right** to load operand B.
   * Set the opcode on `SW[5:0]` and press **BTN Center** to load it.
   * The result of the operation appears on `LED[15:8]`.
   * Press **BTN Up** at any time to reset operands and opcode.

---

## Example Walkthrough

1. Set `SW[7:0] = 00000101` (decimal 5). Press **BTN Left** → loads A=5.
2. Set `SW[7:0] = 00000011` (decimal 3). Press **BTN Right** → loads B=3.
3. Set `SW[5:0] = 100000` (ADD). Press **BTN Center** → loads opcode.
4. `LED[15:8]` shows `00001000` (decimal 8).

Repeat with other opcodes for subtraction, shifts, etc.

---

## Project Structure

```Python
ComputerArchitecture/ALU
├── ALU.srcs
│   ├── constrs_1
│   │   └── new
│   │       └── top_alu.xdc        # Basys3 constraints
│   ├── sim_1
│   │   └── new
│   │       └── tb_top_alu.v       # Testbench
│   └── sources_1
│       └── new
│           ├── alu.v              # ALU module
│           └── top.v              # Top-level module
└── README.md
```

---

## Notes

* All signals are active-high (switches, buttons, LEDs).
* The ALU is parameterized (`NB_DATA`, `NB_OP`) and can be scaled to different bit-widths.
* No debounce is used for push buttons: pressing multiple times is harmless since operands/opcodes are overwritten with the same value.
