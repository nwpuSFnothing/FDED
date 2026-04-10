module uart_rx #(
    parameter integer CLK_FREQ  = 200_000_000,
    parameter integer BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg [7:0]  data_o,
    output reg        done_o
);

    localparam integer CLKS_PER_BIT  = CLK_FREQ / BAUD_RATE;
    localparam integer HALF_CLKS_BIT = CLKS_PER_BIT / 2;

    localparam [1:0] S_IDLE  = 2'd0;
    localparam [1:0] S_START = 2'd1;
    localparam [1:0] S_DATA  = 2'd2;
    localparam [1:0] S_STOP  = 2'd3;

    reg [1:0] state;
    reg [31:0] clk_cnt;
    reg [2:0] bit_idx;
    reg [7:0] data_buf;

    reg rx_d0, rx_d1;

    always @(posedge clk) begin
        rx_d0 <= rx;
        rx_d1 <= rx_d0;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            clk_cnt  <= 32'd0;
            bit_idx  <= 3'd0;
            data_buf <= 8'd0;
            data_o   <= 8'd0;
            done_o   <= 1'b0;
        end else begin
            done_o <= 1'b0;

            case (state)
                S_IDLE: begin
                    clk_cnt <= 32'd0;
                    bit_idx <= 3'd0;

                    if (rx_d1 == 1'b0) begin
                        state <= S_START;
                    end
                end

                S_START: begin
                    if (clk_cnt == HALF_CLKS_BIT - 1) begin
                        clk_cnt <= 32'd0;

                        if (rx_d1 == 1'b0) begin
                            state <= S_DATA;
                            bit_idx <= 3'd0;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 32'd1;
                    end
                end

                S_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 32'd0;
                        data_buf[bit_idx] <= rx_d1;

                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 3'd1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 32'd1;
                    end
                end

                S_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 32'd0;
                        state <= S_IDLE;

                        if (rx_d1 == 1'b1) begin
                            data_o <= data_buf;
                            done_o <= 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 32'd1;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule