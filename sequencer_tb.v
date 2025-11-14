`timescale 1ns/1ps
module sequencer_tb;

  reg         clk, rst_n, start, continue_i;
  reg         rom_we;
  reg  [7:0]  rom_waddr;
  reg  [15:0] rom_wdata;
  wire [4:0]  ctl_a, ctl_b;
  wire [1:0]  ctl_c, ctl_d, ctl_e;
  wire        ready;
  wire [7:0]  pc_dbg;

  sequencer DUT (
    .clk(clk), .rst_n(rst_n), .start(start), .continue_i(continue_i),
    .rom_we(rom_we), .rom_waddr(rom_waddr), .rom_wdata(rom_wdata),
    .ctl_a(ctl_a), .ctl_b(ctl_b), .ctl_c(ctl_c), .ctl_d(ctl_d), .ctl_e(ctl_e),
    .ready(ready), .pc_dbg(pc_dbg)
  );

  // Clock
  initial clk = 0;
  always #5 clk = ~clk;

  // Helper: pack fields -> 16-bit instr  {a[15:11], b[10:6], c[5:4], d[3:2], e[1:0]}
  function [15:0] INSTR;
    input [4:0] a, b;
    input [1:0] c, d, e;
    begin
      INSTR = {a, b, c, d, e};
    end
  endfunction

  integer errors, checks;

  // ROM write task
  task rom_wr;
    input [7:0]  addr;
    input [15:0] data;
    begin
      @(negedge clk);
      rom_waddr <= addr;
      rom_wdata <= data;
      rom_we    <= 1'b1;
      @(posedge clk);
      rom_we    <= 1'b0;
    end
  endtask

  // Expect current decoded fields to match
  task expect_fields;
    input [4:0] ea, eb;
    input [1:0] ec, ed, ee;
    begin
      #1; checks = checks + 5;
      if (ctl_a !== ea) begin $display("ERR ctl_a exp=%0d got=%0d", ea, ctl_a); errors=errors+1; end
      if (ctl_b !== eb) begin $display("ERR ctl_b exp=%0d got=%0d", eb, ctl_b); errors=errors+1; end
      if (ctl_c !== ec) begin $display("ERR ctl_c exp=%0d got=%0d", ec, ctl_c); errors=errors+1; end
      if (ctl_d !== ed) begin $display("ERR ctl_d exp=%0d got=%0d", ed, ctl_d); errors=errors+1; end
      if (ctl_e !== ee) begin $display("ERR ctl_e exp=%0d got=%0d", ee, ctl_e); errors=errors+1; end
    end
  endtask

  initial begin
    // defaults
    rst_n=0; start=0; continue_i=0; rom_we=0; rom_waddr=0; rom_wdata=0;
    errors=0; checks=0;

    // Program a tiny microprogram:
    // 0: normal step      (ctl_c=00), a=1,b=2,d=1,e=2
    // 1: WAIT-for-continue(ctl_c=01), a=3,b=4,d=2,e=3
    // 2: normal step      (ctl_c=00), a=5,b=6,d=0,e=1
    // 3: HALT             (ctl_c=10), a=7,b=8,d=3,e=0
    rom_wr(8'd0, INSTR(5'd1, 5'd2, 2'b00, 2'b01, 2'b10));
    rom_wr(8'd1, INSTR(5'd3, 5'd4, 2'b01, 2'b10, 2'b11));
    rom_wr(8'd2, INSTR(5'd5, 5'd6, 2'b00, 2'b00, 2'b01));
    rom_wr(8'd3, INSTR(5'd7, 5'd8, 2'b10, 2'b11, 2'b00));

    // Release reset
    repeat(2) @(posedge clk); rst_n = 1; @(posedge clk);

    // READY should be high while idle
    #1; checks = checks + 1;
    if (!ready) begin $display("ERR ready should be 1 when idle"); errors=errors+1; end

    // Start a run
    start = 1; 
    @(posedge clk); 
    #1;  // Wait 1ps after the clock edge before clearing start
    start = 0;
    
    // PC=0: normal step → next PC=1
    expect_fields(5'd1,5'd2,2'b00,2'b01,2'b10);
    @(posedge clk);
    #1; 
    checks = checks + 2;
    if (pc_dbg !== 8'd1)  begin $display("ERR PC step exp=1 got=%0d", pc_dbg); errors=errors+1; end
    if ( ready )          begin $display("ERR ready should be 0 while running"); errors=errors+1; end

    // PC=1: WAIT → stall until continue_i=1
    expect_fields(5'd3,5'd4,2'b01,2'b10,2'b11);
    // hold for a few cycles with continue_i=0
    repeat(3) @(posedge clk);
    #1; checks = checks + 1;
    if (pc_dbg !== 8'd1)  begin $display("ERR WAIT did not stall at PC=1"); errors=errors+1; end
    // now release wait
    continue_i = 1; 
    @(posedge clk); 
    #1;  // Wait 1ps after clock edge
    continue_i = 0;

    // PC should advance to 2
    expect_fields(5'd5,5'd6,2'b00,2'b00,2'b01);
    @(posedge clk);
    #1; checks = checks + 1;
    if (pc_dbg !== 8'd3) begin $display("ERR PC step to 3 failed"); errors=errors+1; end

    // PC=3: HALT → stop & READY=1, PC stays at 3
    expect_fields(5'd7,5'd8,2'b10,2'b11,2'b00);
    @(posedge clk); // apply HALT this cycle
    #1; checks = checks + 2;
    if (!ready) begin $display("ERR ready should be 1 after HALT"); errors=errors+1; end
    if (pc_dbg !== 8'd3) begin $display("ERR PC should stay at 3 after HALT, got %0d", pc_dbg); errors=errors+1; end

    if (errors==0) $display("sequencer_tb: PASS (%0d checks)", checks);
    else           $display("sequencer_tb: %0d ERRORS / %0d checks", errors, checks);
    $finish;
  end
endmodule
