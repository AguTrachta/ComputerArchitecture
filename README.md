# ComputerArchitecture

This repository contains Verilog projects for the **Basys 3** board.  

Currently, it includes the following implementations:
- **ALU**
- **UART** 
- **RISC-V**

## How to run the RISC-V Debug UI

```bash
cd RISC-V/riscv-debug-ui
uv pip install -e .
uv run uvicorn app.main:app --reload --port 8080
```

Then open `http://localhost:8080/` in your browser.

## Authors
- Agustín Pallardó ([@djpallax](https://github.com/djpallax))
- Agustín Trachta ([@AguTrachta](https://github.com/AguTrachta))
