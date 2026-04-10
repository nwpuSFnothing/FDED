module top (
    input  wire clk_p,
    input  wire clk_n,
    output wire uart_txd
);

    wire clk_200m;
    wire rst_n;
    assign rst_n = 1'b1;

    IBUFDS #(
        .DIFF_TERM("FALSE"),
        .IBUF_LOW_PWR("TRUE")
    ) u_ibufds_clk (
        .I (clk_p),
        .IB(clk_n),
        .O (clk_200m)
    );

    reg [31:0] cnt;
    reg        tx_start;
    reg [7:0]  tx_data;
    wire       tx_busy;

    uart_tx #(
        .CLK_FREQ (200_000_000),
        .BAUD_RATE(115200)
    ) u_uart_tx (
        .clk    (clk_200m),
        .rst_n  (rst_n),
        .start_i(tx_start),
        .data_i (tx_data),
        .tx     (uart_txd),
        .busy_o (tx_busy)
    );

    always @(posedge clk_200m) begin
        if (!rst_n) begin
            cnt      <= 32'd0;
            tx_start <= 1'b0;
            tx_data  <= 8'h55;   // 'U'
        end else begin
            tx_start <= 1'b0;

            if (cnt == 32'd100_000_000 - 1) begin
                cnt <= 32'd0;
                if (!tx_busy) begin
                    tx_data  <= 8'h55;   // 'U'
                    tx_start <= 1'b1;
                end
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end

endmodule