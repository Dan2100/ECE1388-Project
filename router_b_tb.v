`timescale 1ns/1ps
module router_b_tb;

  parameter W = 24;

  // DUT I/O
  reg  [W-1:0] A_data, B_data, RQ, RD;
  reg  [1:0]   sel_R, sel_S, sel_I;
  reg          inv_R, inv_S;
  wire [W-1:0] R, S, I;
  wire         msb_R, msb_S;

  router_b #(.W(W)) DUT (
    .A_data(A_data), .B_data(B_data), .RQ(RQ), .RD(RD),
    .sel_R(sel_R), .sel_S(sel_S),
    .inv_R(inv_R), .inv_S(inv_S),
    .sel_I(sel_I),
    .R(R), .S(S), .I(I), .msb_R(msb_R), .msb_S(msb_S)
  );

  // Distinct source patterns
  localparam [W-1:0] PA  = 24'h12_3456;
  localparam [W-1:0] PB  = 24'hAB_CDEF;
  localparam [W-1:0] PRQ = 24'h0F_F00D;
  localparam [W-1:0] PRD = 24'hC0_FFEE;

  // Loop counters / book-keeping (must be module-scope in Verilog-2001)
  integer a, b, c, d, i_sel, tests, errors;

  // Expected value temporaries (also declare at module-scope)
  reg [W-1:0] expR, expS, expI;

  // Helpers to choose expected sources
  function [W-1:0] pickR;
    input [1:0] sel;
    begin
      case(sel)
        2'b00: pickR = PA;
        2'b01: pickR = PRQ;
        2'b10: pickR = {W{1'b0}};
        default: pickR = {W{1'b1}};
      endcase
    end
  endfunction

  function [W-1:0] pickS;
    input [1:0] sel;
    begin
      case(sel)
        2'b00: pickS = PB;
        2'b01: pickS = PRD;
        2'b10: pickS = {W{1'b0}};
        default: pickS = {W{1'b1}};
      endcase
    end
  endfunction

  function [W-1:0] pickI;
    input [1:0] sel;
    begin
      case(sel)
        2'b00: pickI = {W{1'b0}};                 // 0
        2'b01: pickI = {{(W-1){1'b0}}, 1'b1};     // +1
        2'b10: pickI = {W{1'b1}};                 // -1 (all ones)
        default: pickI = {W{1'b0}};
      endcase
    end
  endfunction

  initial begin
    // Drive distinct sources
    A_data = PA; B_data = PB; RQ = PRQ; RD = PRD;
    tests = 0; errors = 0;

    // Iterate all mux choices + inversion flags + immediates (0,+1,-1)
    for (a=0; a<4; a=a+1)
    for (b=0; b<4; b=b+1)
    for (c=0; c<2; c=c+1)
    for (d=0; d<2; d=d+1) begin
      sel_R = a[1:0];
      sel_S = b[1:0];
      inv_R = c[0:0];
      inv_S = d[0:0];

      for (i_sel=0; i_sel<3; i_sel=i_sel+1) begin
        sel_I = i_sel[1:0];

        #1; tests = tests + 1;

        // Compute expected
        expR = pickR(sel_R);
        if (inv_R) expR = ~expR;

        expS = pickS(sel_S);
        if (inv_S) expS = ~expS;

        expI = pickI(sel_I);

        // Checks
        if (R !== expR) begin
          $display("ERR R: sel_R=%0d inv_R=%0d exp=%h got=%h", sel_R, inv_R, expR, R);
          errors = errors + 1;
        end
        if (S !== expS) begin
          $display("ERR S: sel_S=%0d inv_S=%0d exp=%h got=%h", sel_S, inv_S, expS, S);
          errors = errors + 1;
        end
        if (I !== expI) begin
          $display("ERR I: sel_I=%0d exp=%h got=%h", sel_I, expI, I);
          errors = errors + 1;
        end
        if (msb_R !== R[W-1]) begin
          $display("ERR msb_R mismatch"); errors = errors + 1;
        end
        if (msb_S !== S[W-1]) begin
          $display("ERR msb_S mismatch"); errors = errors + 1;
        end
      end
    end

    if (errors==0) $display("router_b_tb: PASS (%0d tests)", tests);
    else           $display("router_b_tb: %0d ERRORS / %0d tests", errors, tests);

    $finish;
  end

endmodule
