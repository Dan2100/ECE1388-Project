`timescale 1ns/1ps

// Router A
module router_a
#(parameter W=24, parameter ADDRW=5)
(
  input  [W-1:0]      DATA_IN,
  input  [W-1:0]      RESULT,
  input  [ADDRW-1:0]  CTL_A,
  input  [ADDRW-1:0]  CTL_B,
  input  [ADDRW-1:0]  DIR_EXT,
  input               WRITE_REQ,
  input               READY,
  input  [1:0]        sel_data,    // 0=DATA_IN, 1=RESULT, 2=ZERO
  input               sel_dira,    // 0=CTL_A,   1=DIR_EXT
  input               sel_dirb,    // 0=CTL_B,   1=DIR_EXT
  input  [1:0]        sel_write,   // 0=WR, 1=WR&READY, 2=0, 3=1
  output reg [W-1:0]  db_data,
  output      [ADDRW-1:0] db_dira,
  output      [ADDRW-1:0] db_dirb,
  output reg          db_write
);

  // Data mux
  always @* begin
    case (sel_data)
      2'd0: db_data = DATA_IN;
      2'd1: db_data = RESULT;
      2'd2: db_data = {W{1'b0}};
      default: db_data = RESULT;
    endcase
  end

  // Address muxes
  assign db_dira = sel_dira ? DIR_EXT : CTL_A;
  assign db_dirb = sel_dirb ? DIR_EXT : CTL_B;

  // Write-enable mux / gating
  always @* begin
    case (sel_write)
      2'd0: db_write = WRITE_REQ;
      2'd1: db_write = WRITE_REQ & READY;
      2'd2: db_write = 1'b0;
      default: db_write = 1'b1;
    endcase
  end
endmodule
