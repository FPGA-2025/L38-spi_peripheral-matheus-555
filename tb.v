`timescale 1ns/1ps

module tb();

    reg clk;
    reg rst_n;
    reg [7:0] data_in;
    wire [7:0] data_out;
    wire busy;
    wire data_out_valid;
    reg data_in_valid;
    reg mosi;
    wire miso;
    reg sck;
    reg cs;

    integer i, bit_idx;

    // Clock do sistema
    initial clk = 0;
    always #1 clk = ~clk;

    // SPI Slave
    SPI_Peripheral #(
        .SPI_BITS_PER_WORD(8),
        .SPI_MODE(0)
    ) u_SPI_Peripheral (
        .clk(clk),
        .rst_n(rst_n),
        .sck(sck),
        .cs(cs),
        .mosi(mosi),
        .miso(miso),
        .data_in_valid(data_in_valid),
        .data_out_valid(data_out_valid),
        .busy(busy),
        .data_in(data_in),
        .data_out(data_out)
    );

    // Mestre SPI simples
    reg [7:0] spi_byte_to_send;

    // Vetores de teste
    reg [7:0] test_data [0:3];

    // Clock SPI
    initial sck = 0;
    always #5 sck = ~sck;

    // Variável para capturar MISO
    reg [7:0] miso_received;

    // Task para enviar um byte via SPI (usa variável global)
    task send_spi_byte;
        integer bit_idx;
        begin
            cs = 0;  // ativa slave antes do primeiro bit
            //@(negedge sck);  // pequena sincronização inicial

            for (bit_idx = 7; bit_idx >= 0; bit_idx = bit_idx - 1) begin
                @(negedge sck);
                mosi = spi_byte_to_send[bit_idx];
                @(posedge sck);  // slave lê na borda de subida
                miso_received[bit_idx] = miso; // captura o bit enviado pelo slave
            end

            @(posedge sck);  // espera mais um ciclo para garantir que slave registre o último bit
            cs = 1;          // desativa CS
        end
    endtask

    // Testbench principal
    initial begin
        $dumpfile("saida.vcd");
        $dumpvars(0, tb);
        // Inicialização
        clk = 0;
        rst_n = 0;
        cs = 1;
        sck = 0;
        mosi = 0;
        data_in_valid = 0;

        // Reset
        #10 rst_n = 1;
        #10 rst_n = 0;
        #10 rst_n = 1;

        // Dados de teste
        test_data[0] = 8'hA5;
        test_data[1] = 8'h5A;
        test_data[2] = 8'hFF;
        test_data[3] = 8'h00;

        // Envio de bytes
        for (i = 0; i < 4; i = i + 1) begin
            data_in_valid = 1;
            data_in = test_data[i];
            @(posedge clk);
            @(posedge clk);
            data_in_valid = 0;
            spi_byte_to_send = test_data[i];
            send_spi_byte;

            if (data_out == test_data[i])
                $display("Test %0d: OK! Received=%h, Expected=%h", i, data_out, test_data[i]);
            else
                $display("Test %0d: ERRO! Received=%h, Expected=%h", i, data_out, test_data[i]);

            // Verifica miso
            if (miso_received == test_data[i])
                $display("Test %0d miso: OK! Received=%h, Expected=%h", i, miso_received, test_data[i]);
            else
                $display("Test %0d miso: ERRO! Received=%h, Expected=%h", i, miso_received, test_data[i]);

            @(posedge clk);
        end

        $display("All SPI tests finished.");
        $finish;
    end

endmodule
