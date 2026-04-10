`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/04/10 21:22:50
// Design Name: 
// Module Name: sha256_single_block
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module sha256_single_block (
    input  wire            clk,
    input  wire            rst_n,
    input  wire            start_i,
    input  wire [7:0]      msg_len_i,            // <= 55
    input  wire [8*55-1:0] msg_data_i,           // byte0在最高位

    output reg             busy_o,
    output reg             done_o,
    output reg [255:0]     digest_o
);

    localparam [2:0] S_IDLE  = 3'd0;
    localparam [2:0] S_BUILD = 3'd1;
    localparam [2:0] S_WINIT = 3'd2;
    localparam [2:0] S_COMP  = 3'd3;
    localparam [2:0] S_ADD   = 3'd4;
    localparam [2:0] S_DONE  = 3'd5;

    reg [2:0] state;

    reg [511:0] block;
    reg [31:0]  W [0:63];

    reg [31:0] H0, H1, H2, H3, H4, H5, H6, H7;
    reg [31:0] a, b, c, d, e, f, g, h;
    reg [6:0]  round;

    reg [31:0] a_n, b_n, c_n, d_n, e_n, f_n, g_n, h_n;
    reg [31:0] w_cur, t1, t2;

    reg [63:0] bit_len;

    integer i;
    integer word_idx;

    function [31:0] ROTR32;
        input [31:0] x;
        input [4:0] n;
        begin
            ROTR32 = (x >> n) | (x << (32 - n));
        end
    endfunction

    function [31:0] CH;
        input [31:0] x, y, z;
        begin
            CH = (x & y) ^ (~x & z);
        end
    endfunction

    function [31:0] MAJ;
        input [31:0] x, y, z;
        begin
            MAJ = (x & y) ^ (x & z) ^ (y & z);
        end
    endfunction

    function [31:0] BSIG0;
        input [31:0] x;
        begin
            BSIG0 = ROTR32(x,2) ^ ROTR32(x,13) ^ ROTR32(x,22);
        end
    endfunction

    function [31:0] BSIG1;
        input [31:0] x;
        begin
            BSIG1 = ROTR32(x,6) ^ ROTR32(x,11) ^ ROTR32(x,25);
        end
    endfunction

    function [31:0] SSIG0;
        input [31:0] x;
        begin
            SSIG0 = ROTR32(x,7) ^ ROTR32(x,18) ^ (x >> 3);
        end
    endfunction

    function [31:0] SSIG1;
        input [31:0] x;
        begin
            SSIG1 = ROTR32(x,17) ^ ROTR32(x,19) ^ (x >> 10);
        end
    endfunction

    function [31:0] K;
        input [5:0] idx;
        begin
            case (idx)
                6'd0 : K = 32'h428a2f98;  6'd1 : K = 32'h71374491;
                6'd2 : K = 32'hb5c0fbcf;  6'd3 : K = 32'he9b5dba5;
                6'd4 : K = 32'h3956c25b;  6'd5 : K = 32'h59f111f1;
                6'd6 : K = 32'h923f82a4;  6'd7 : K = 32'hab1c5ed5;
                6'd8 : K = 32'hd807aa98;  6'd9 : K = 32'h12835b01;
                6'd10: K = 32'h243185be;  6'd11: K = 32'h550c7dc3;
                6'd12: K = 32'h72be5d74;  6'd13: K = 32'h80deb1fe;
                6'd14: K = 32'h9bdc06a7;  6'd15: K = 32'hc19bf174;
                6'd16: K = 32'he49b69c1;  6'd17: K = 32'hefbe4786;
                6'd18: K = 32'h0fc19dc6;  6'd19: K = 32'h240ca1cc;
                6'd20: K = 32'h2de92c6f;  6'd21: K = 32'h4a7484aa;
                6'd22: K = 32'h5cb0a9dc;  6'd23: K = 32'h76f988da;
                6'd24: K = 32'h983e5152;  6'd25: K = 32'ha831c66d;
                6'd26: K = 32'hb00327c8;  6'd27: K = 32'hbf597fc7;
                6'd28: K = 32'hc6e00bf3;  6'd29: K = 32'hd5a79147;
                6'd30: K = 32'h06ca6351;  6'd31: K = 32'h14292967;
                6'd32: K = 32'h27b70a85;  6'd33: K = 32'h2e1b2138;
                6'd34: K = 32'h4d2c6dfc;  6'd35: K = 32'h53380d13;
                6'd36: K = 32'h650a7354;  6'd37: K = 32'h766a0abb;
                6'd38: K = 32'h81c2c92e;  6'd39: K = 32'h92722c85;
                6'd40: K = 32'ha2bfe8a1;  6'd41: K = 32'ha81a664b;
                6'd42: K = 32'hc24b8b70;  6'd43: K = 32'hc76c51a3;
                6'd44: K = 32'hd192e819;  6'd45: K = 32'hd6990624;
                6'd46: K = 32'hf40e3585;  6'd47: K = 32'h106aa070;
                6'd48: K = 32'h19a4c116;  6'd49: K = 32'h1e376c08;
                6'd50: K = 32'h2748774c;  6'd51: K = 32'h34b0bcb5;
                6'd52: K = 32'h391c0cb3;  6'd53: K = 32'h4ed8aa4a;
                6'd54: K = 32'h5b9cca4f;  6'd55: K = 32'h682e6ff3;
                6'd56: K = 32'h748f82ee;  6'd57: K = 32'h78a5636f;
                6'd58: K = 32'h84c87814;  6'd59: K = 32'h8cc70208;
                6'd60: K = 32'h90befffa;  6'd61: K = 32'ha4506ceb;
                6'd62: K = 32'hbef9a3f7;  6'd63: K = 32'hc67178f2;
            endcase
        end
    endfunction

    always @(*) begin
        if (round < 16)
            w_cur = W[round];
        else
            w_cur = SSIG1(W[round-2]) + W[round-7] + SSIG0(W[round-15]) + W[round-16];

        t1 = h + BSIG1(e) + CH(e,f,g) + K(round[5:0]) + w_cur;
        t2 = BSIG0(a) + MAJ(a,b,c);

        a_n = t1 + t2;
        b_n = a;
        c_n = b;
        d_n = c;
        e_n = d + t1;
        f_n = e;
        g_n = f;
        h_n = g;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            busy_o   <= 1'b0;
            done_o   <= 1'b0;
            digest_o <= 256'd0;
            block    <= 512'd0;
            round    <= 7'd0;

            H0 <= 32'd0; H1 <= 32'd0; H2 <= 32'd0; H3 <= 32'd0;
            H4 <= 32'd0; H5 <= 32'd0; H6 <= 32'd0; H7 <= 32'd0;

            a <= 32'd0; b <= 32'd0; c <= 32'd0; d <= 32'd0;
            e <= 32'd0; f <= 32'd0; g <= 32'd0; h <= 32'd0;

            bit_len <= 64'd0;

            for (i = 0; i < 64; i = i + 1)
                W[i] <= 32'd0;
        end else begin
            done_o <= 1'b0;

            case (state)
                S_IDLE: begin
                    busy_o <= 1'b0;
                    if (start_i) begin
                        busy_o <= 1'b1;
                        state  <= S_BUILD;
                    end
                end

                S_BUILD: begin
                    block   <= 512'd0;
                    bit_len <= {56'd0, msg_len_i} << 3;

                    for (i = 0; i < 64; i = i + 1)
                        W[i] <= 32'd0;

                    // 先清零整个block
                    block <= 512'd0;

                    // 拷贝0~54字节消息
                    for (i = 0; i < 55; i = i + 1) begin
                        if (i < msg_len_i)
                            block[511 - i*8 -: 8] <= msg_data_i[8*(55-i)-1 -: 8];
                    end

                    // 追加0x80
                    block[511 - msg_len_i*8 -: 8] <= 8'h80;

                    // 最后64位写入bit长度（大端）
                    block[63:0] <= ({56'd0, msg_len_i} << 3);

                    H0 <= 32'h6a09e667; H1 <= 32'hbb67ae85;
                    H2 <= 32'h3c6ef372; H3 <= 32'ha54ff53a;
                    H4 <= 32'h510e527f; H5 <= 32'h9b05688c;
                    H6 <= 32'h1f83d9ab; H7 <= 32'h5be0cd19;

                    state <= S_WINIT;
                end

                S_WINIT: begin
                    for (word_idx = 0; word_idx < 16; word_idx = word_idx + 1)
                        W[word_idx] <= block[511 - word_idx*32 -: 32];

                    a <= H0; b <= H1; c <= H2; d <= H3;
                    e <= H4; f <= H5; g <= H6; h <= H7;

                    round <= 7'd0;
                    state <= S_COMP;
                end

                S_COMP: begin
                    if (round >= 16)
                        W[round] <= w_cur;

                    a <= a_n; b <= b_n; c <= c_n; d <= d_n;
                    e <= e_n; f <= f_n; g <= g_n; h <= h_n;

                    if (round == 7'd63)
                        state <= S_ADD;
                    else
                        round <= round + 7'd1;
                end

                S_ADD: begin
                    H0 <= H0 + a;
                    H1 <= H1 + b;
                    H2 <= H2 + c;
                    H3 <= H3 + d;
                    H4 <= H4 + e;
                    H5 <= H5 + f;
                    H6 <= H6 + g;
                    H7 <= H7 + h;

                    digest_o <= {H0 + a, H1 + b, H2 + c, H3 + d,
                                 H4 + e, H5 + f, H6 + g, H7 + h};

                    state <= S_DONE;
                end

                S_DONE: begin
                    done_o <= 1'b1;
                    busy_o <= 1'b0;
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule