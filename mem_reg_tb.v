`timescale 1ns/1ps
module mem_reg_tb;

  // Keep small DEPTH for quick test; you can bump to 40 later
  parameter W     = 24;
  parameter DEPTH = 8;
  parameter ADDRW = 3;

  // DUT I/O
  reg                 clk;

  // Data Bank
  reg                 db_we;
  reg  [ADDRW-1:0]    db_waddr, db_raddr_a, db_raddr_b;
  reg  [W-1:0]        db_wdata;
  wire [W-1:0]        db_rdata_a, db_rdata_b;

  // RQ / RD
  reg                 rq_we, rd_we;
  reg  [W-1:0]        rq_d, rd_d;
  wire [W-1:0]        rq_q, rd_q;

  // Temp address regs (declare at module scope)
  reg  [ADDRW-1:0]    ai, bi;

  // Loop counters / bookkeeping
  integer i, errors, checks;

  // DUT
  mem_reg #(.W(W), .DEPTH(DEPTH), .ADDRW(ADDRW), .FORWARD(1)) DUT (
    .clk(clk),
    .db_we(db_we), .db_waddr(db_waddr), .db_wdata(db_wdata),
    .db_raddr_a(db_raddr_a), .db_raddr_b(db_raddr_b),
    .db_rdata_a(db_rdata_a), .db_rdata_b(db_rdata_b),
    .rq_we(rq_we), .rq_d(rq_d), .rq_q(rq_q),
    .rd_we(rd_we), .rd_d(rd_d), .rd_q(rd_q)
  );

  // Clock
  initial clk = 0;
  always #5 clk = ~clk; // 100 MHz

  // Pattern helper
  function [W-1:0] patt;
    input integer i;
    begin
      patt = {8'hA5, i[7:0], 8'h5A};
    end
  endfunction

  // Tasks
  task db_write;
    input [ADDRW-1:0] addr;
    input [W-1:0]     data;
    begin
      @(negedge clk);
      db_waddr <= addr;
      db_wdata <= data;
      db_we    <= 1'b1;
      @(posedge clk);   // write occurs on this edge
      @(negedge clk);
      db_we    <= 1'b0;
    end
  endtask

  task db_read_check;
    input [ADDRW-1:0] addr_a;
    input [ADDRW-1:0] addr_b;
    input [W-1:0]     exp_a;
    input [W-1:0]     exp_b;
    begin
      db_raddr_a <= addr_a;
      db_raddr_b <= addr_b;
      #1; checks = checks + 2;
      if (db_rdata_a !== exp_a) begin
        $display("ERR DB A: addr=%0d exp=%h got=%h", addr_a, exp_a, db_rdata_a);
        errors = errors + 1;
      end
      if (db_rdata_b !== exp_b) begin
        $display("ERR DB B: addr=%0d exp=%h got=%h", addr_b, exp_b, db_rdata_b);
        errors = errors + 1;
      end
    end
  endtask

  task rq_write_check;
    input [W-1:0] data;
    begin
      rq_d  <= data;
      rq_we <= 1'b1;
      @(posedge clk);
      rq_we <= 1'b0;
      #1; checks = checks + 1;
      if (rq_q !== data) begin
        $display("ERR RQ: exp=%h got=%h", data, rq_q);
        errors = errors + 1;
      end
    end
  endtask

  task rd_write_check;
    input [W-1:0] data;
    begin
      rd_d  <= data;
      rd_we <= 1'b1;
      @(posedge clk);
      rd_we <= 1'b0;
      #1; checks = checks + 1;
      if (rd_q !== data) begin
        $display("ERR RD: exp=%h got=%h", data, rd_q);
        errors = errors + 1;
      end
    end
  endtask

  // Stimulus
  initial begin
    // init
    db_we=0; db_waddr=0; db_wdata=0; db_raddr_a=0; db_raddr_b=0;
    rq_we=0; rq_d=0; rd_we=0; rd_d=0; errors=0; checks=0;

    // 1) Write patterns into all DB locations
    for (i=0; i<DEPTH; i=i+1) begin
      ai = i[ADDRW-1:0];     // width truncation is OK
      db_write(ai, patt(i));
    end

    // 2) Read them back via both ports
    for (i=0; i<DEPTH; i=i+1) begin
      ai = i[ADDRW-1:0];
      bi = (DEPTH-1 - i);    // truncates to ADDRW
      db_read_check(ai, bi, patt(i), patt(DEPTH-1 - i));
    end

    // 3) Read-during-write hazard (write-through)
    @(negedge clk);
      db_waddr   <= 3;                // literal auto-truncates to ADDRW
      db_wdata   <= 24'hDE_ADBE;
      db_we      <= 1'b1;
      db_raddr_a <= 3;                // same address
      db_raddr_b <= 2;
    #1; checks = checks + 1;
      if (db_rdata_a !== 24'hDE_ADBE) begin
        $display("ERR FWD: expected %h got %h", 24'hDE_ADBE, db_rdata_a);
        errors = errors + 1;
      end
    @(posedge clk); @(negedge clk);
      db_we <= 1'b0;

    // 4) RQ / RD write checks (no reset; write before read)
    rq_write_check(24'h00_1111);
    rd_write_check(24'h22_3333);

    // 5) Ensure RQ/RD hold when WE=0
    rq_d <= 24'hAA_BBCC; rd_d <= 24'hCC_DDEE;
    @(posedge clk); #1; checks = checks + 2;
    if (rq_q !== 24'h00_1111) begin $display("ERR RQ hold"); errors=errors+1; end
    if (rd_q !== 24'h22_3333) begin $display("ERR RD hold"); errors=errors+1; end

    if (errors==0) $display("mem_reg_tb: PASS (%0d checks)", checks);
    else           $display("mem_reg_tb: %0d ERRORS / %0d checks", errors, checks);
    $finish;
  end

endmodule
