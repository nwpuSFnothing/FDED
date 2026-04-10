module uart_tx #(
    parameter integer CLK_FREQ  = 200_000_000,
    parameter integer BAUD_RATE = 115200
)(
    input  wire      clk,
    input  wire      rst_n,
    input  wire      start_i,
    input  wire [7:0] data_i,
    output reg       tx,
    output reg       busy_o
);

    localparam integer BAUD_CNT = CLK_FREQ / BAUD_RATE;

    reg [15:0] baud_cnt;
    reg [3:0]  bit_cnt;
    reg [9:0]  tx_shift;

    always @(posedge clk) begin
        if (!rst_n) begin
            tx       <= 1'b1;
            busy_o   <= 1'b0;
            baud_cnt <= 16'd0;
            bit_cnt  <= 4'd0;
            tx_shift <= 10'h3FF;
        end else begin
            if (!busy_o) begin
                tx <= 1'b1;
                if (start_i) begin
                    busy_o   <= 1'b1;
                    tx_shift <= {1'b1, data_i, 1'b0}; // stop + data + start
                    baud_cnt <= BAUD_CNT - 1;
                    bit_cnt  <= 4'd0;
                    tx       <= 1'b0;
                end
            end else begin
                if (baud_cnt == 0) begin
                    baud_cnt <= BAUD_CNT - 1;
                    bit_cnt  <= bit_cnt + 1'b1;

                    if (bit_cnt < 9) begin
                        tx <= tx_shift[bit_cnt + 1];
                    end else begin
                        tx <= 1'b1;
                        busy_o <= 1'b0;
                    end
                end else begin
                    baud_cnt <= baud_cnt - 1'b1;
                end
            end
        end
    end

endmodule