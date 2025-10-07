#!/bin/bash

# Compila todos os arquivos .v
iverilog -o tb *.v

# Remove saída anterior
rm -f saida.out

# Executa o testbench e salva a saída
./tb > saida.out

# Mostra apenas as linhas com "OK" ou "ERRO"
grep -oE '\b(OK|ERRO)\b' saida.out
