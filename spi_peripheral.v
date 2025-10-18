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

    localparam integer CNT_W = $clog2(SPI_BITS_PER_WORD);

    // Sincronizadores e detectores de borda
    reg [1:0] sck_sync, cs_sync, mosi_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sck_sync  <= {2{CPOL}};
            cs_sync   <= 2'b11;
            mosi_sync <= 2'b00;
        end else begin
            sck_sync  <= {sck_sync[0], sck};
            cs_sync   <= {cs_sync[0], cs};
            mosi_sync <= {mosi_sync[0], mosi};
        end
    end
    wire sck_s  = sck_sync[1];
    wire cs_s   = cs_sync[1];
    wire mosi_s = mosi_sync[1];

    reg sck_s_d, cs_s_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sck_s_d <= CPOL;
            cs_s_d  <= 1'b1;
        end else begin
            sck_s_d <= sck_s;
            cs_s_d  <= cs_s;
        end
    end
    wire sck_rise = ( sck_s & ~sck_s_d);
    wire sck_fall = (~sck_s &  sck_s_d);
    wire cs_fall  = (~cs_s  &  cs_s_d);
    wire cs_rise  = ( cs_s  & ~cs_s_d);

    wire sample_is_rise = (CPHA == CPOL);
    wire sample_edge    = sample_is_rise ? sck_rise : sck_fall;

    // Registradores principais
    reg [SPI_BITS_PER_WORD-1:0] tx_buf;
    reg [SPI_BITS_PER_WORD-1:0] tx_shift;
    reg [SPI_BITS_PER_WORD-1:0] rx_shift;
    reg [CNT_W:0]               bit_cnt;
    reg                         miso_q;

    // Estrutura da Máquina de Estados
    localparam [0:0] S_IDLE = 1'b0, 
                     S_TRANSFER = 1'b1;
    
    reg current_state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= S_IDLE;
        else        current_state <= next_state;
    end

    always @(*) begin
        next_state = current_state;
        case (current_state)
            S_IDLE:     if (cs_fall) next_state = S_TRANSFER;
            S_TRANSFER: if (cs_rise) next_state = S_IDLE;
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) tx_buf <= {SPI_BITS_PER_WORD{1'b0}};
        else if (data_in_valid) tx_buf <= data_in;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy           <= 1'b0;
            rx_shift       <= {SPI_BITS_PER_WORD{1'b0}};
            tx_shift       <= {SPI_BITS_PER_WORD{1'b0}};
            bit_cnt        <= {(CNT_W+1){1'b0}};
            data_out       <= {SPI_BITS_PER_WORD{1'b0}};
            data_out_valid <= 1'b0;
        end else begin
            data_out_valid <= 1'b0;

            if (current_state == S_IDLE && next_state == S_TRANSFER) begin
                busy     <= 1'b1;
                rx_shift <= {SPI_BITS_PER_WORD{1'b0}};
                tx_shift <= tx_buf;
                bit_cnt  <= SPI_BITS_PER_WORD - 1;
            end

            if (current_state == S_TRANSFER) begin
                if(cs_rise) busy <= 1'b0;

                if (sample_edge) begin
                    rx_shift <= {rx_shift[SPI_BITS_PER_WORD-2:0], mosi_s};
                    if (bit_cnt != 0)
                        bit_cnt <= bit_cnt - 1'b1;
                    if (bit_cnt == 0) begin
                        data_out       <= {rx_shift[SPI_BITS_PER_WORD-2:0], mosi_s};
                        data_out_valid <= 1'b1;
                    end
                end
            end
        end
    end

    // =======================================================================
    //  Bloco Generate para Transmissão (MISO) - Otimizado para Clareza
    // =======================================================================
    generate
    // Implementação para Modos CPHA=0 (0 e 2)
    if (CPHA == 1'b0) begin : g_tx_cpha0
        reg hold_shift; // Flag para segurar o primeiro deslocamento

        // Quando CS cai, armamos a flag 'hold_shift'.
        // Isso garante que o primeiro bit (MSB) não seja deslocado prematuramente.
        always @(negedge cs or negedge rst_n) begin
            if (!rst_n) hold_shift <= 1'b0;
            else        hold_shift <= 1'b1;
        end

        // Na primeira borda de clock (aqui, posedge sck), o mestre lê o MSB.
        // Após essa leitura, desarmamos a flag para permitir os próximos deslocamentos.
        always @(posedge sck or negedge cs) begin
            if (!cs) hold_shift <= 1'b0;
        end

        // Nas bordas de deslocamento (negedge sck), atualizamos o MISO.
        // Isso só acontece se a flag 'hold_shift' estiver desarmada.
        always @(negedge sck or negedge cs) begin
            if (!cs) begin
                if (!hold_shift) begin
                    miso_q   <= tx_shift[SPI_BITS_PER_WORD-1];
                    tx_shift <= {tx_shift[SPI_BITS_PER_WORD-2:0], 1'b0};
                end
            end
        end
        assign miso = miso_q;

    // Implementação para Modos CPHA=1 (1 e 3)
    end else begin : g_tx_cpha1
        wire shift_edge = sample_is_rise ? sck_fall : sck_rise;
        
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                 miso_q <= 1'b0;
            end else if (!cs_s && shift_edge) begin
                // Na borda de deslocamento, coloca o MSB no MISO e prepara o próximo bit.
                miso_q   <= tx_shift[SPI_BITS_PER_WORD-1];
                tx_shift <= {tx_shift[SPI_BITS_PER_WORD-2:0], 1'b0};
            end
        end
        assign miso = miso_q;
    end
    endgenerate

endmodule
