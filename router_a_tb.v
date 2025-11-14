`timescale 1ns/1ps
module router_a_tb;
  parameter W=24, ADDRW=5;

  reg  [W-1:0]      DATA_IN, RESULT;
  reg  [ADDRW-1:0]  CTL_A, CTL_B, DIR_EXT;
  reg               WRITE_REQ, READY;
  reg  [1:0]        sel_data, sel_write;
  reg               sel_dira, sel_dirb;

  wire [W-1:0]      db_data;
  wire [ADDRW-1:0]  db_dira, db_dirb;
  wire              db_write;

  router_a #(.W(W), .ADDRW(ADDRW)) DUT (
    .DATA_IN(DATA_IN), .RESULT(RESULT),
    .CTL_A(CTL_A), .CTL_B(CTL_B), .DIR_EXT(DIR_EXT),
    .WRITE_REQ(WRITE_REQ), .READY(READY),
    .sel_data(sel_data), .sel_dira(sel_dira),
    .sel_dirb(sel_dirb), .sel_write(sel_write),
    .db_data(db_data), .db_dira(db_dira), .db_dirb(db_dirb), .db_write(db_write)
  );

  // Distinct patterns
  localparam [W-1:0]      DIN  = 24'h123456;
  localparam [W-1:0]      RES  = 24'hC0FFEE;
  localparam [ADDRW-1:0]  ASEL = 5'h03;
  localparam [ADDRW-1:0]  BSEL = 5'h1C;
  localparam [ADDRW-1:0]  DEXT = 5'h12;

  integer sd,sda,sdb,sw,wr,rdy, tests, errors;

  // Expected helpers
  function [W-1:0] exp_data; input [1:0] sd;
    begin
      case(sd)
        2'd0: exp_data = DIN;
        2'd1: exp_data = RES;
        2'd2: exp_data = {W{1'b0}};
        default: exp_data = RES;
      endcase
    end
  endfunction

  function [ADDRW-1:0] exp_dira; input sel;
    begin exp_dira = sel ? DEXT : ASEL; end
  endfunction

  function [ADDRW-1:0] exp_dirb; input sel;
    begin exp_dirb = sel ? DEXT : BSEL; end
  endfunction

  function exp_write; input [1:0] sw; input wr, ready;
    begin
      case(sw)
        2'd0: exp_write = wr;
        2'd1: exp_write = wr & ready;
        2'd2: exp_write = 1'b0;
        default: exp_write = 1'b1;
      endcase
    end
  endfunction

  initial begin
    DATA_IN=DIN; RESULT=RES; CTL_A=ASEL; CTL_B=BSEL; DIR_EXT=DEXT;
    tests=0; errors=0;

    for (sd=0; sd<4; sd=sd+1)
    for (sda=0; sda<2; sda=sda+1)
    for (sdb=0; sdb<2; sdb=sdb+1)
    for (sw=0; sw<4; sw=sw+1)
    for (wr=0; wr<2; wr=wr+1)
    for (rdy=0; rdy<2; rdy=rdy+1) begin
      sel_data  = sd[1:0];
      sel_dira  = sda[0:0];
      sel_dirb  = sdb[0:0];
      sel_write = sw[1:0];
      WRITE_REQ = wr[0:0];
      READY     = rdy[0:0];
      #1; tests = tests + 1;

      if (db_data !== exp_data(sel_data)) begin
        $display("ERR data: sel_data=%0d exp=%h got=%h",
                  sel_data, exp_data(sel_data), db_data);
        errors = errors + 1;
      end
      if (db_dira !== exp_dira(sel_dira)) begin
        $display("ERR dira: sel_dira=%0d exp=%0d got=%0d",
                 sel_dira, exp_dira(sel_dira), db_dira);
        errors = errors + 1;
      end
      if (db_dirb !== exp_dirb(sel_dirb)) begin
        $display("ERR dirb: sel_dirb=%0d exp=%0d got=%0d",
                 sel_dirb, exp_dirb(sel_dirb), db_dirb);
        errors = errors + 1;
      end
      if (db_write !== exp_write(sel_write, WRITE_REQ, READY)) begin
        $display("ERR write: sel_write=%0d wr=%0d rdy=%0d exp=%0d got=%0d",
                 sel_write, WRITE_REQ, READY,
                 exp_write(sel_write, WRITE_REQ, READY), db_write);
        errors = errors + 1;
      end
    end

    if (errors==0) $display("Router A: %0d tests PASSED :)", tests);
    else           $display("Router A: %0d tests, %0d ERRORS :(", tests, errors);
    $finish;
  end
endmodule
