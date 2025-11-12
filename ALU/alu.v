`timescale 1ns/1ps

// Arithmetic Unit matching the IEICE 2016 Kalman Filter VLSI architecture
// Includes:
// - Sign and magnitude fixed-point format: [23]=sign, [22:14]=integer (9 bits), [13:0]=fraction (14 bits)
// - Adder/Subtractor working in sign‑mag
// - 24x24 sign‑mag multiplier (combinational)
// - 24-cycle multiplicative-inverse using bit-by-bit successive approximation with internal comparator

module alu (
    input  wire         clk,
    input  wire         rst,
    input  wire [23:0]  R,
    input  wire [23:0]  S,
    input  wire         ctl_f,
    input  wire         ctl_e,
    output wire [23:0]  result,
    output wire         sign,
    output wire         cont
);

    wire [23:0] add_out;
    wire [47:0] mult_out;
    wire [23:0] mult_inv_out;
    wire [23:0] mult_inv_out_sign;
    wire [23:0] inv_out;
    wire [23:0] Y;
    wire        inv_rdy;

    wire sign_r = R[23];
    wire sign_s = S[23];
    wire sign_xor = sign_r ^ sign_s;

    adder_subs u_add (
        .x(R),
        .y(S),
        .op(~ctl_f),
        .sr(add_out)
    );

    multiplier u_mult (
        .x(R),
        .y(Y),
        .m(mult_out)
    );

    multiplicative_inverse u_inv (
        .clk(clk),
        .rst(rst),
        .m(mult_out),
        .i(inv_out),
        .rdy(inv_rdy)
    );

    assign ctrl_nand = ~(ctl_e & ctl_f);
    assign Y = ctrl_nand ? S : inv_out; // mux for Y input

    assign mult_inv_out = ctl_e ? inv_out : mult_out[47:24]; // mux for mult vs inv
    assign sign_out = ctrl_nand ? sign_xor : sign_s; // mux for sign output
    assign mult_inv_out_sign = {sign_out, mult_inv_out}; // combine with sign mux

    assign result = ctl_f ? mult_inv_out_sign : add_out; // mux for add vs mult/inv
    assign cont = inv_rdy | ctrl_nand; // continue signal for inv only

endmodule

// ------------------------------------------------------
// Adder/Subtractor
// -----------------------------------------------------
module adder_subs (
    input  wire [23:0] x,
    input  wire [23:0] y,
    input  wire        op,
    output wire  [23:0] sr
);
    wire sx = x[23];
    wire sy = y[23];
    wire [23:0] y_eff = (op ? {sy, y[22:0]} : 24'b0);

    wire [23:0] x_mag = {1'b0, x[22:0]};
    wire [23:0] y_mag = {1'b0, y_eff[22:0]};

    wire add_sign = sx ^ y_eff[23];

    wire [23:0] add_res = add_sign ?
                          (x_mag > y_mag ? {1'b0, x_mag[22:0] - y_mag[22:0]} : {1'b0, y_mag[22:0] - x_mag[22:0]}) :
                          ({1'b0, x_mag[22:0] + y_mag[22:0]});

    wire final_sign = (x_mag >= y_mag) ? sx : y_eff[23];

    assign sr = {final_sign, add_res[22:0]};
endmodule

// ------------------------------------------------------
// 24x24 Multiplier
// ------------------------------------------------------
module multiplier (
    input  wire [23:0] x,
    input  wire [23:0] y,
    output wire [47:0] m
);
    // Separate sign and magnitude
    wire sign_x = x[23];
    wire sign_y = y[23];
    wire [22:0] mag_x = x[22:0];
    wire [22:0] mag_y = y[22:0];

    // Multiply magnitudes (full precision)
    wire [45:0] full_product = mag_x * mag_y;

    // Scale back to Q9.14 by shifting right 14 bits
    wire [31:0] scaled = full_product >> 14;

    // Combine sign and scaled magnitude (24-bit result)
    assign m = { (sign_x ^ sign_y), scaled[22:0], 24'b0 };
endmodule

// ------------------------------------------------------
// Multiplicative Inverse
// ------------------------------------------------------
module multiplicative_inverse (
    input  wire        clk,
    input  wire        rst,
    input  wire [47:0] m,    // input operand (S9.14, sign-magnitude)
    output reg  [23:0] i,    // output reciprocal (S9.14, sign-magnitude)
    output reg         rdy
);
    reg bit_pos;

    always @(posedge clk or posedge rst) begin
        $display("Inverse Step: m=%h, i=%h, bit_pos=%d", m, i, bit_pos);

        if (rst) begin
            i <= 24'b0;
            bit_pos <= 23;
            rdy <= 0;
        end else begin
            if (bit_pos == 0) begin
                rdy <= 1;
            end else begin
                i[bit_pos] <= 1'b1;
                if (m > 24'h004000) begin // 1 in Q9.14
                    i[bit_pos] <= 1'b0;
                end
                bit_pos <= bit_pos - 1;
        end
    end
end

endmodule