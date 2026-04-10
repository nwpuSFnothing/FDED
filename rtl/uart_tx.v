module uart_tx #(
    parameter integer CLK_FREQ  = 200_000_000,
    parameter integer BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start_i,
    input  wire [7:0] data_i,
    output reg        tx,
    output reg        busy_o
);

    localparam integer BAUD_CNT_MAX = CLK_FREQ / BAUD_RATE;

    reg [31:0] baud_cnt;
    reg [3:0]  bit_cnt;
    reg [9:0]  frame_data;

    always @(posedge clk) begin
        if (!rst_n) begin
            tx         <= 1'b1;
            busy_o     <= 1'b0;
            baud_cnt   <= 32'd0;
            bit_cnt    <= 4'd0;
            frame_data <= 10'h3FF;
        end else begin
            if (!busy_o) begin
                tx <= 1'b1;
                baud_cnt <= 32'd0;
                bit_cnt <= 4'd0;

                if (start_i) begin
                    busy_o <= 1'b1;
                    frame_data <= {1'b1, data_i, 1'b0}; // stop, data[7:0], start
                    tx <= 1'b0;                         // 先发起始位
                    baud_cnt <= 32'd0;
                    bit_cnt <= 4'd0;
                end
            end else begin
                if (baud_cnt == BAUD_CNT_MAX - 1) begin
                    baud_cnt <= 32'd0;
                    bit_cnt  <= bit_cnt + 4'd1;

                    case (bit_cnt)
                        4'd0: tx <= frame_data[1];
                        4'd1: tx <= frame_data[2];
                        4'd2: tx <= frame_data[3];
                        4'd3: tx <= frame_data[4];
                        4'd4: tx <= frame_data[5];
                        4'd5: tx <= frame_data[6];
                        4'd6: tx <= frame_data[7];
                        4'd7: tx <= frame_data[8];
                        4'd8: tx <= frame_data[9];
                        4'd9: begin
                            tx <= 1'b1;
                            busy_o <= 1'b0;
                        end
                        default: begin
                            tx <= 1'b1;
                            busy_o <= 1'b0;
                        end
                    endcase
                end else begin
                    baud_cnt <= baud_cnt + 32'd1;
                end
            end
        end
    end

endmodule