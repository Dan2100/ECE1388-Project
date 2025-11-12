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
    wire [23:0] inv_out;
    wire        inv_rdy;

    wire sign_r = R[23];
    wire sign_s = S[23];
    wire sign_xor = sign_r ^ sign_s;

    adder_subs u_add (
        .x(R),
        .y(S),
        .op(ctl_f),
        .sr(add_out)
    );

    multiplier u_mult (
        .x(R),
        .y(S),
        .m(mult_out)
    );

    multiplicative_inverse u_inv (
        .clk(clk),
        .rst(rst),
        .m(mult_out[47:24]),
        .i(inv_out),
        .rdy(inv_rdy)
    );

    assign result = ctl_f ? add_out : mult_out[47:24];
    assign sign   = ctl_f ? sign_xor : sign_r;
    assign cont = inv_rdy | ctl_e;

endmodule

// ------------------------------------------------------
// Adder/Subtractor
// ------------------------------------------------------
module adder_subs (
    input  wire [23:0] x,
    input  wire [23:0] y,
    input  wire        op,
    output reg  [23:0] sr
);
    wire sx = x[23];
    wire sy = y[23];
    wire [23:0] y_eff = (op ? {sy, y[22:0]} : {~sy, y[22:0]});

    wire [23:0] x_mag = {1'b0, x[22:0]};
    wire [23:0] y_mag = {1'b0, y_eff[22:0]};

    wire add_sign = sx ^ y_eff[23];

    wire [23:0] add_res = add_sign ?
                          (x_mag > y_mag ? {1'b0, x_mag[22:0] - y_mag[22:0]} : {1'b0, y_mag[22:0] - x_mag[22:0]}) :
                          ({1'b0, x_mag[22:0] + y_mag[22:0]});

    wire final_sign = (x_mag >= y_mag) ? sx : y_eff[23];

    always @(*) begin
        sr = {final_sign, add_res[22:0]};
    end
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
    input  wire [23:0] m,
    output reg [23:0]  i,
    output reg         rdy
);
    reg [23:0] trial;
    reg [5:0]  bitpos;
    reg busy;

    wire [47:0] test_mul = trial * m[22:0];
    wire geq_one = test_mul[47:24] >= 24'h000001;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            i <= 0;
            trial <= 0;
            bitpos <= 0;
            rdy <= 0;
            busy <= 0;
        end else begin

            if (!busy) begin
                trial <= 0;
                bitpos <= 23;
                rdy <= 0;
                busy <= 1;
            end else begin
                if (bitpos == 6'd63) begin
                    i <= trial;
                    rdy <= 1;
                    busy <= 0;
                end else begin
                    trial <= trial | (24'h1 << bitpos);
                    if (geq_one) begin
                        trial <= trial & ~(24'h1 << bitpos);
                    end
                    bitpos <= bitpos - 1;
                end
            end
        end
    end
endmodule
