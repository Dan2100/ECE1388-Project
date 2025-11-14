// -----------------------------------------------------------------------------
// router_b.v
// Router B: select operands for the ALU.
//  - Picks R from {A port, RQ, ZERO, ALL_ONES}
//  - Picks S from {B port, RD, ZERO, ALL_ONES}
//  - Optional bitwise invert on R or S (can be tied off if not used)
//  - Immediate I: {ZERO, +1, -1} for adder carry/offset use
//  - Exposes MSB(R)/MSB(S) to the ALU (useful for sign logic)
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module router_b
#(parameter W=24)
(
  // Operand sources
  input  [W-1:0] A_data,   // from Data Bank read port A
  input  [W-1:0] B_data,   // from Data Bank read port B
  input  [W-1:0] RQ,       // temp register RQ
  input  [W-1:0] RD,       // temp register RD

  // Selects
  input  [1:0]   sel_R,    // 00=A_data, 01=RQ, 10=ZERO, 11=ALL_ONES
  input  [1:0]   sel_S,    // 00=B_data, 01=RD, 10=ZERO, 11=ALL_ONES

  // Optional modifiers
  input          inv_R,    // 1 = bitwise invert selected R (default 0)
  input          inv_S,    // 1 = bitwise invert selected S (default 0)

  // Immediate select (for ALU use)
  input  [1:0]   sel_I,    // 00=ZERO, 01=+1 (LSB=1), 10=ALL_ONES(-1), 11=ZERO

  // Outputs to ALU
  output [W-1:0] R,
  output [W-1:0] S,
  output [W-1:0] I,
  output         msb_R,
  output         msb_S
);

  // ---- R source mux ----
  reg [W-1:0] R_mux;
  always @* begin
    case (sel_R)
      2'b00: R_mux = A_data;
      2'b01: R_mux = RQ;
      2'b10: R_mux = {W{1'b0}};
      default: R_mux = {W{1'b1}}; // all ones
    endcase
  end

  // ---- S source mux ----
  reg [W-1:0] S_mux;
  always @* begin
    case (sel_S)
      2'b00: S_mux = B_data;
      2'b01: S_mux = RD;
      2'b10: S_mux = {W{1'b0}};
      default: S_mux = {W{1'b1}}; // all ones
    endcase
  end

  // ---- Optional inversion (bitwise) ----
  assign R = inv_R ? ~R_mux : R_mux;
  assign S = inv_S ? ~S_mux : S_mux;

  // ---- Immediate word ----
  // NOTE: "+1" is encoded as ...0001 (Q format users: interpret per your ALU).
  reg [W-1:0] I_r;
  always @* begin
    case (sel_I)
      2'b00: I_r = {W{1'b0}};               // 0
      2'b01: I_r = {{(W-1){1'b0}}, 1'b1};   // +1
      2'b10: I_r = {W{1'b1}};               // -1 (all ones)
      default: I_r = {W{1'b0}};
    endcase
  end
  assign I = I_r;

  // ---- MSBs to ALU ----
  assign msb_R = R[W-1];
  assign msb_S = S[W-1];

endmodule
