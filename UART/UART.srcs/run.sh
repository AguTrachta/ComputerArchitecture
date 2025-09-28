#!/bin/bash
set -e

# limpiar restos anteriores
rm -rf xsim.dir tb_top_sim *.log *.jou *.pb *.wdb *.vcd

# compilar
xvlog sources_1/new/top.v \
      sources_1/new/fifo.v \
      sources_1/new/uart_tx.v \
      sources_1/new/uart_rx.v \
      sources_1/new/baud_gen.v \
      sources_1/new/adder5.v \
      sim_1/new/tb_top_adder.v

# elaborar
xelab tb_top -s tb_top_sim

# simular
xsim tb_top_sim --runall

# abrir GTKWave si el VCD existe
if [ -f tb_top.vcd ]; then
    gtkwave tb_top.vcd &
else
    echo ">>> No se generó tb_top.vcd, revisá tu testbench."
fi
