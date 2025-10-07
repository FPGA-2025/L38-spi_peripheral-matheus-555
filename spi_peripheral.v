/*
============================================================
| TABELA DE MODOS SPI (CPOL/CPHA)                          |
============================================================
| Modo | CPOL | CPHA | Clock Inativo  | Leitura (MOSI)    | Escrita (MISO)     |
|------|------|------|----------------|-------------------|--------------------|
|  0   |  0   |  0   |   Nível baixo  | Borda de subida   | Borda de descida   |
|  1   |  0   |  1   |   Nível baixo  | Borda de descida  | Borda de subida    |
|  2   |  1   |  0   |   Nível alto   | Borda de descida  | Borda de subida    |
|  3   |  1   |  1   |   Nível alto   | Borda de subida   | Borda de descida   |
------------------------------------------------------------

Definições:
- CPOL (Polaridade do Clock):
    0 = Clock inativo em nível baixo
    1 = Clock inativo em nível alto

- CPHA (Fase do Clock):
    0 = Dados são amostrados na primeira borda, deslocados na segunda
    1 = Dados são deslocados na primeira borda, amostrados na segunda

Temporização:
- Leitura (MOSI): quando o escravo lê o dado enviado pelo mestre
- Escrita (MISO): quando o escravo coloca o próximo bit para ser lido

Este módulo ajusta seu comportamento automaticamente com base no SPI_MODE.
============================================================
*/

module SPI_Peripheral #(
    parameter SPI_BITS_PER_WORD = 8,
    parameter SPI_MODE          = 0  // 0: CPOL=0, CPHA=0; 1: CPOL=0, CPHA=1; 2: CPOL=1, CPHA=0; 3: CPOL=1, CPHA=1
)(
    input  wire clk,
    input  wire rst_n,

    input  wire sck,
    input  wire cs,
    input  wire mosi,
    output wire miso,

    input  wire data_in_valid,
    output reg  data_out_valid,
    output reg  busy,

    input  wire [SPI_BITS_PER_WORD-1:0] data_in,
    output reg  [SPI_BITS_PER_WORD-1:0] data_out
);
    // Mode decoding
    localparam CPOL = (SPI_MODE == 2 || SPI_MODE == 3);
    localparam CPHA = (SPI_MODE == 1 || SPI_MODE == 3);


endmodule
