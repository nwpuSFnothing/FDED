module top (
    input  wire clk_p,
    input  wire clk_n,
    input  wire uart_rxd,
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

    wire [7:0] rx_data;
    wire       rx_done;

    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;

    uart_rx #(
        .CLK_FREQ (200_000_000),
        .BAUD_RATE(115200)
    ) u_uart_rx (
        .clk    (clk_200m),
        .rst_n  (rst_n),
        .rx     (uart_rxd),
        .data_o (rx_data),
        .done_o (rx_done)
    );

    uart_tx #(
        .CLK_FREQ (200_000_000),
        .BAUD_RATE(115200)
    ) u_uart_tx (
        .clk     (clk_200m),
        .rst_n   (rst_n),
        .start_i (tx_start),
        .data_i  (tx_data),
        .tx      (uart_txd),
        .busy_o  (tx_busy)
    );

    localparam integer MAX_PAYLOAD = 55;

    localparam [2:0] S_LEN_HI   = 3'd0;
    localparam [2:0] S_LEN_LO   = 3'd1;
    localparam [2:0] S_RECV     = 3'd2;
    localparam [2:0] S_SHA_WAIT = 3'd3;
    localparam [2:0] S_SEND     = 3'd4;

    reg [2:0]  state;
    reg [15:0] frame_len;
    reg [15:0] recv_cnt;
    reg [15:0] send_cnt;

    reg [7:0] mem [0:MAX_PAYLOAD-1];

    reg [8*55-1:0] sha_msg_data;
    reg [7:0]      sha_msg_len;
    reg            sha_start;
    wire           sha_busy;
    wire           sha_done;
    wire [255:0]   sha_digest;

    reg tx_req;

    integer i;

    sha256_single_block u_sha256 (
        .clk        (clk_200m),
        .rst_n      (rst_n),
        .start_i    (sha_start),
        .msg_len_i  (sha_msg_len),
        .msg_data_i (sha_msg_data),
        .busy_o     (sha_busy),
        .done_o     (sha_done),
        .digest_o   (sha_digest)
    );

    always @(posedge clk_200m) begin
        if (!rst_n) begin
            state        <= S_LEN_HI;
            frame_len    <= 16'd0;
            recv_cnt     <= 16'd0;
            send_cnt     <= 16'd0;
            tx_data      <= 8'd0;
            tx_start     <= 1'b0;
            tx_req       <= 1'b0;
            sha_start    <= 1'b0;
            sha_msg_len  <= 8'd0;
            sha_msg_data <= {(8*55){1'b0}};

            for (i = 0; i < MAX_PAYLOAD; i = i + 1) begin
                mem[i] <= 8'd0;
            end
        end else begin
            tx_start  <= 1'b0;
            sha_start <= 1'b0;

            case (state)
                S_LEN_HI: begin
                    recv_cnt <= 16'd0;
                    send_cnt <= 16'd0;
                    tx_req   <= 1'b0;

                    if (rx_done) begin
                        frame_len[15:8] <= rx_data;
                        state <= S_LEN_LO;
                    end
                end

                S_LEN_LO: begin
                    if (rx_done) begin
                        frame_len[7:0] <= rx_data;

                        if ({frame_len[15:8], rx_data} == 16'd0) begin
                            state <= S_LEN_HI;
                        end else if ({frame_len[15:8], rx_data} > MAX_PAYLOAD) begin
                            state <= S_LEN_HI;
                        end else begin
                            recv_cnt <= 16'd0;
                            state <= S_RECV;
                        end
                    end
                end

                S_RECV: begin
                    if (rx_done) begin
                        mem[recv_cnt] <= rx_data;
                        recv_cnt <= recv_cnt + 16'd1;

                        if (recv_cnt + 16'd1 >= frame_len) begin
                            for (i = 0; i < 55; i = i + 1) begin
                                if (i < frame_len) begin
                                    if (i == recv_cnt)
                                        sha_msg_data[8*(55-i)-1 -: 8] <= rx_data;
                                    else
                                        sha_msg_data[8*(55-i)-1 -: 8] <= mem[i];
                                end else begin
                                    sha_msg_data[8*(55-i)-1 -: 8] <= 8'h00;
                                end
                            end

                            sha_msg_len <= frame_len[7:0];
                            sha_start   <= 1'b1;
                            send_cnt    <= 16'd0;
                            tx_req      <= 1'b0;
                            state       <= S_SHA_WAIT;
                        end
                    end
                end

                S_SHA_WAIT: begin
                    if (sha_done) begin
                        send_cnt <= 16'd0;
                        tx_req   <= 1'b0;
                        state    <= S_SEND;
                    end
                end

                S_SEND: begin
                    if (!tx_busy && !tx_req && send_cnt < 16'd32) begin
                        tx_data  <= sha_digest[255 - send_cnt*8 -: 8];
                        tx_start <= 1'b1;
                        tx_req   <= 1'b1;
                    end

                    if (tx_req && tx_busy) begin
                        tx_req   <= 1'b0;
                        send_cnt <= send_cnt + 16'd1;
                    end

                    if ((send_cnt == 16'd32) && !tx_busy && !tx_req) begin
                        state <= S_LEN_HI;
                    end
                end

                default: begin
                    state <= S_LEN_HI;
                end
            endcase
        end
    end

endmodule