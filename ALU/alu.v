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
    wire [22:0] mult_inv_out;
    wire [23:0] mult_inv_out_sign;
    wire [23:0] inv_out;
    wire [23:0] Y;
    wire        inv_rdy;

    wire sign_r = R[23];
    wire sign_s = S[23];
    
    wire sign_xor;
    wire zero_check = (~|R[22:0] || ~|S[22:0]); // reduction OR for negative 0 handling

    adder_subs u_add (
        .x(R),
        .y(S),
        .op(ctl_f),
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
    
    assign sign_xor = zero_check ? 0 : sign_r ^ sign_s; // handle negative 0s

    assign ctrl_nand = ~(ctl_e & ctl_f);
    assign Y = ctrl_nand ? S : inv_out; // mux for Y input

    assign mult_inv_out = ctl_e ? inv_out : mult_out[36:14]; // mux for mult vs inv
    assign sign_out = ctrl_nand ? sign_xor : sign_r; // mux for sign output
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
    output wire [23:0] sr
);
    // Split sign and magnitude
    wire sign_x = x[23];
    wire sign_y = y[23];
    wire [22:0] mag_x = x[22:0];
    wire [22:0] mag_y = y[22:0];

    // Effective sign of Y after subtract
    wire eff_sign_y = op ? ~sign_y : sign_y;

    // Determine if signs match
    wire same_sign = (sign_x == eff_sign_y);

    // Add magnitudes if same sign
    wire [22:0] add_mag = mag_x + mag_y;

    // Subtract magnitudes if opposite sign
    wire [22:0] sub_mag = (mag_x == mag_y) ? 0 :
                           (mag_x > mag_y) ? (mag_x - mag_y) : (mag_y - mag_x);

    // Determine result sign
    wire sign_res = same_sign ? sign_x :
                     (mag_x == mag_y) ? 1'b0 : // +0 for cancellation
                     (mag_x > mag_y) ? sign_x : eff_sign_y;

    // Select magnitude based on sign match
    wire [22:0] mag_res = same_sign ? add_mag : sub_mag;

    // Combine sign + magnitude into S9.14
    assign sr = {sign_res, mag_res};

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

    // Multiply magnitudes (full precision 23x23 → 46 bits)
    wire [45:0] raw_product = mag_x * mag_y;

    assign m = raw_product;
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
    reg [4:0] bit_pos;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            i <= 24'hFFFFFF; //start with all 1s
            bit_pos <= 22; //start at MSB - not sign
            rdy <= 0;
        end else begin
            if (bit_pos != 0) begin
                if (m[36:14] > 24'h004000) begin //if m is greater than 1
                    i[bit_pos] <= 1'b0; //decrease i by half
                end
                bit_pos <= bit_pos - 1; //move to next bit
            end else begin //if gone through all bits, end
                rdy <= 1'b1; //done
            end
        end
    end

endmodule