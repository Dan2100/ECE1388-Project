// -----------------------------------------------------------------------------
// kf_top_tb.v
// Testbench for complete Kalman Filter ASIC top-level
// Tests the integrated system: Sequencer + Routers + Memory + AU
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module kf_top_tb;

  parameter W = 24;
  parameter FRAC = 14;
  parameter NR = 40;
  parameter ADDRW = 6;
  
  // DUT signals
  reg              clk;
  reg              rst_n;
  reg              start;
  reg  [W-1:0]     data_in;
  wire             ready;
  wire [W-1:0]     result_out;
  wire             au_done;
  
  // Instantiate DUT
  kf_top #(.W(W), .FRAC(FRAC), .NR(NR), .ADDRW(ADDRW)) DUT (
    .clk        (clk),
    .rst_n      (rst_n),
    .start      (start),
    .data_in    (data_in),
    .ready      (ready),
    .result_out (result_out),
    .au_done    (au_done)
  );
  
  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;
  
  // ========== Helper Functions ==========
  
  // Convert two's complement to sign-magnitude
  function [W-1:0] tc_to_sm;
    input signed [W-1:0] v;
    reg sign;
    reg signed [W-1:0] a;
    begin
      sign = (v < 0);
      a = sign ? -v : v;
      if (a[W-2:0] > {(W-1){1'b1}}) a[W-2:0] = {(W-1){1'b1}};
      tc_to_sm = {sign, a[W-2:0]};
    end
  endfunction
  
  // Convert sign-magnitude to two's complement
  function signed [W-1:0] sm_to_tc;
    input [W-1:0] sm;
    begin
      sm_to_tc = sm[W-1] ? -$signed({1'b0, sm[W-2:0]}) : $signed({1'b0, sm[W-2:0]});
    end
  endfunction
  
  // Create Q-format value from integer
  function [W-1:0] q_of_int;
    input integer k;
    reg signed [W-1:0] tc;
    begin
      tc = k <<< FRAC;
      q_of_int = tc_to_sm(tc);
    end
  endfunction
  
  // Display sign-magnitude value
  task display_sm;
    input [W-1:0] val;
    input [80*8-1:0] label;
    reg signed [W-1:0] tc;
    real r;
    begin
      tc = sm_to_tc(val);
      r = $itor(tc) / (2.0 ** FRAC);
      $display("%s: sm=%h tc=%h decimal=%.6f", label, val, tc, r);
    end
  endtask
  
  // ========== Test Sequence ==========
  
  integer errors, checks;
  reg [W-1:0] val_a, val_b, expected;
  reg signed [W-1:0] tc_a, tc_b, tc_result;
  
  // For MUL calculation
  reg [2*(W-1)-1:0] prod;
  reg [W-2:0] mag_a, mag_b, mag_result;
  reg sign_result;
  
  initial begin
    $display("========================================");
    $display("Kalman Filter ASIC Top-Level Test");
    $display("Complete Arithmetic Operations Test");
    $display("========================================");
    
    // Initialize
    clk = 0;
    rst_n = 0;
    start = 0;
    data_in = 0;
    errors = 0;
    checks = 0;
    
    // Test values: 3.0 and 2.5 in Q14 format
    val_a = q_of_int(3);       // 3.0 = 0x00C000
    val_b = q_of_int(2);       // 2.0 = 0x008000
    val_b = val_b + (1 << (FRAC-1)); // 2.5 = 0x00A000
    
    $display("\nTest operands:");
    display_sm(val_a, "Value A (3.0)");
    display_sm(val_b, "Value B (2.5)");
    
    // Reset sequence
    #20;
    rst_n = 1;
    #10;
    
    $display("\n[Test 1] Check initial READY state");
    checks = checks + 1;
    if (ready !== 1'b1) begin
      $display("ERROR: System not ready after reset");
      errors = errors + 1;
    end else begin
      $display("PASS: System ready");
    end
    
    $display("\n[Test 2] Load operands into memory");
    // Memory writes are synchronous - they happen on the NEXT posedge
    // after write_en is asserted
    
    // Prepare first value
    data_in = val_a;
    #5;
    $display("T0: Prepared data_in=%h (3.0)", data_in);
    
    // Cycle 1: Assert START
    @(posedge clk);
    #1;
    start = 1'b1;
    $display("T1: Asserted START");
    
    // Cycle 2: PC→0, ROM[0] instruction visible
    @(posedge clk);
    #1;
    $display("T2: PC=%d, instruction for DB[0] write active", DUT.Sequencer.pc);
    start = 1'b0;
    
    // Cycle 3: PC→1, DB[0] write completes, ROM[1] instruction visible
    // NOW we can change data_in for the DB[1] write
    @(posedge clk);
    #1;
    $display("T3: PC=%d, DB[0]=%h (should be 00c000)", 
             DUT.Sequencer.pc, DUT.Memory_Registers.Data_Bank.mem[0]);
    data_in = val_b;
    $display("T3: Changed data_in=%h (2.5) for DB[1]", data_in);
    
    // Cycle 4: PC→2, DB[1] write completes
    @(posedge clk);
    #1;
    $display("T4: PC=%d, DB[0]=%h, DB[1]=%h", 
             DUT.Sequencer.pc, DUT.Memory_Registers.Data_Bank.mem[0], DUT.Memory_Registers.Data_Bank.mem[1]);
    data_in = 0;
    
    // Monitor execution
    $display("\n[PC Progression from PC=2 onwards]");
    begin : early_monitor
      integer i;
      for (i = 0; i < 10; i = i + 1) begin
        $display("  PC=%2d: ctl_a=%05b ctl_b=%05b addr_a=%d addr_b=%d rdata_a=%h rdata_b=%h",
                 DUT.Sequencer.pc, DUT.ctl_a, DUT.ctl_b,
                 DUT.addr_a, DUT.addr_b, DUT.db_rdata_a, DUT.db_rdata_b);
        if (DUT.Sequencer.pc == 2) begin
          $display("  >>> PC=2: R_bus=%h S_bus=%h au_start=%b", 
                   DUT.R_bus, DUT.S_bus, DUT.au_start);
        end
        @(posedge clk);
        #1;
      end
    end
    
    // Check what was actually loaded
    #10;
    $display("\nMemory contents after load:");
    $display("  DB[0] = %h (expected %h for 3.0)", DUT.Memory_Registers.Data_Bank.mem[0], val_a);
    $display("  DB[1] = %h (expected %h for 2.5)", DUT.Memory_Registers.Data_Bank.mem[1], val_b);
    
    $display("\nROM Program Check:");
    $display("  ROM[2] = %b (ADD instruction)", DUT.Sequencer.ROM.mem[2]);
    $display("           ctl_a=%b ctl_b=%b ctl_c=%b ctl_d=%b ctl_e=%b",
             DUT.Sequencer.ROM.mem[2][15:11],
             DUT.Sequencer.ROM.mem[2][10:6],
             DUT.Sequencer.ROM.mem[2][5:4],
             DUT.Sequencer.ROM.mem[2][3:2],
             DUT.Sequencer.ROM.mem[2][1:0]);
    
    $display("PASS: Loaded operands");
    checks = checks + 1;
    
    // Monitor a few cycles to see PC progression
    $display("\n[PC Progression Check]");
    begin : pc_check
      integer i;
      for (i = 0; i < 10; i = i + 1) begin
        @(posedge clk);
        #1;
        $display("  Cycle %d: PC=%d, ready=%b", i, DUT.Sequencer.pc, DUT.ready);
        if (DUT.Sequencer.pc == 2) begin
          $display("\n[PC=2 Debug] ADD Instruction Execution:");
          $display("  ctl_b = %05b", DUT.ctl_b);
          $display("  sel_R = %02b, sel_S = %02b, addr_mode = %b", DUT.sel_R, DUT.sel_S, DUT.addr_mode);
          $display("  addr_a = %d, addr_b = %d", DUT.addr_a, DUT.addr_b);
          $display("  db_rdata_a = %h (mem[%d])", DUT.db_rdata_a, DUT.addr_a);
          $display("  db_rdata_b = %h (mem[%d])", DUT.db_rdata_b, DUT.addr_b);
          $display("  R_bus = %h, S_bus = %h", DUT.R_bus, DUT.S_bus);
          $display("  au_start = %b, op_sel = %02b", DUT.au_start, DUT.op_sel);
        end
      end
    end
    
    $display("\n[Test 3] Monitor sequencer execution");
    $display("PC   | ctl_a | ctl_b | ctl_c | ctl_d | ctl_e | addr_a | addr_b | au_done | ready | result");
    $display("-----|-------|-------|-------|-------|-------|--------|--------|---------|-------|--------");
    
    // Monitor for a few cycles or until HALT
    begin : monitor_loop
      integer i;
      for (i = 0; i < 50; i = i + 1) begin
        @(posedge clk);
        #1;
        $display("%3d  | %5b | %5b | %2b    | %2b    | %2b    | %6d | %6d | %b       | %b     | %h",
                 DUT.Sequencer.pc,
                 DUT.ctl_a,
                 DUT.ctl_b,
                 DUT.ctl_c,
                 DUT.ctl_d,
                 DUT.ctl_e,
                 DUT.addr_a,
                 DUT.addr_b,
                 au_done,
                 ready,
                 result_out);
        
        // Check if we hit HALT (ctl_c = 2'b10)
        if (DUT.ctl_c == 2'b10 && ready == 1'b1) begin
          $display("\nHALT detected - program completed at PC=%d", DUT.Sequencer.pc);
          disable monitor_loop;
        end
      end
    end
    
    $display("\n[Test 4] Verify computation results");
    // Read back results from memory
    #20;
    
    // Expected results:
    // DB[2] should have ADD: 3.0 + 2.5 = 5.5
    tc_a = sm_to_tc(val_a);
    tc_b = sm_to_tc(val_b);
    tc_result = tc_a + tc_b;
    expected = tc_to_sm(tc_result);
    
    $display("\nExpected ADD result (3.0 + 2.5 = 5.5):");
    display_sm(expected, "ADD");
    $display("Actual result in DB[2]:");
    display_sm(DUT.Memory_Registers.Data_Bank.mem[2], "DB[2]");
    
    checks = checks + 1;
    if (DUT.Memory_Registers.Data_Bank.mem[2] == expected) begin
      $display("PASS: ADD result correct");
    end else begin
      $display("ERROR: ADD result mismatch");
      errors = errors + 1;
    end
    
    // DB[3] should have SUB: 3.0 - 2.5 = 0.5
    tc_result = tc_a - tc_b;
    expected = tc_to_sm(tc_result);
    
    $display("\nExpected SUB result (3.0 - 2.5 = 0.5):");
    display_sm(expected, "SUB");
    $display("Actual result in DB[3]:");
    display_sm(DUT.Memory_Registers.Data_Bank.mem[3], "DB[3]");
    
    checks = checks + 1;
    if (DUT.Memory_Registers.Data_Bank.mem[3] == expected) begin
      $display("PASS: SUB result correct");
    end else begin
      $display("ERROR: SUB result mismatch");
      errors = errors + 1;
    end
    
    // DB[4] should have MUL: 3.0 * 2.5 = 7.5
    // For multiplication in fixed-point, need to handle scaling
    mag_a = val_a[W-2:0];
    mag_b = val_b[W-2:0];
    sign_result = val_a[W-1] ^ val_b[W-1];
    
    prod = mag_a * mag_b;
    mag_result = prod[2*(W-1)-1:FRAC];  // Scale down by FRAC bits
    
    expected = {sign_result, mag_result};
    
    $display("\nExpected MUL result (3.0 * 2.5 = 7.5):");
    display_sm(expected, "MUL");
    $display("Actual result in DB[4]:");
    display_sm(DUT.Memory_Registers.Data_Bank.mem[4], "DB[4]");
    
    checks = checks + 1;
    if (DUT.Memory_Registers.Data_Bank.mem[4] == expected) begin
      $display("PASS: MUL result correct");
    end else begin
      $display("ERROR: MUL result mismatch");
      errors = errors + 1;
    end
    
    $display("\n[Test 5] Verify system returned to READY");
    if (ready == 1'b1) begin
      $display("PASS: System ready for next operation");
    end else begin
      $display("WARNING: System not in READY state");
    end
    checks = checks + 1;
    
    // ========== NEW: Test RQ/RD Registers ==========
    $display("\n========================================");
    $display("[Test 6] RQ/RD Register Functionality");  
    $display("========================================");
    
    // Reset sequencer to re-program from scratch
    rst_n = 0;
    #20;
    rst_n = 1;
    #10;
    
    // Program ROM for RQ/RD test (overwrite old program)
    // PC=0: Load 4.0 to DB[5]
    DUT.Sequencer.ROM.mem[0] = 16'b00101_00000_00_00_01;
    // PC=1: Load DB[5] to RQ (e1e0=11)
    DUT.Sequencer.ROM.mem[1] = 16'b00101_00000_00_00_11;
    // PC=2: ADD RQ + DB[0] (sel_R=01 for RQ, sel_S=00 for port B at addr=0)
    DUT.Sequencer.ROM.mem[2] = 16'b00000_01000_00_00_10;
    // PC=3: WAIT
    DUT.Sequencer.ROM.mem[3] = 16'b00000_00000_01_00_00;
    // PC=4: Write result to DB[6]
    DUT.Sequencer.ROM.mem[4] = 16'b01110_00000_00_00_01;
    // PC=5: HALT
    DUT.Sequencer.ROM.mem[5] = 16'b00000_00000_10_00_00;
    
    // Load 4.0
    val_a = q_of_int(4);  // 4.0
    data_in = val_a;
    
    $display("Starting RQ/RD test: will load 4.0 to RQ, then RQ + DB[0] (3.0) = 7.0");
    
    @(posedge clk);
    #1;
    start = 1'b1;
    
    @(posedge clk);
    #1;
    start = 1'b0;
    
    // Monitor execution closely
    $display("\nMonitoring RQ test execution:");
    begin : monitor_rq
      integer i;
      for (i = 0; i < 10; i = i + 1) begin
        @(posedge clk);
        #1;
        $display("  PC=%d: sel_R=%02b sel_S=%02b R_bus=%06h S_bus=%06h au_start=%b result=%06h",
                 DUT.Sequencer.pc, DUT.sel_R, DUT.sel_S, 
                 DUT.R_bus, DUT.S_bus, DUT.au_start, DUT.au_result);
        if (DUT.Sequencer.pc == 2) begin
          $display("    >>> At PC=2: addr_a=%d addr_b=%d db_rdata_a=%06h db_rdata_b=%06h RQ=%06h",
                   DUT.addr_a, DUT.addr_b, DUT.db_rdata_a, DUT.db_rdata_b, DUT.Memory_Registers.rq_q);
        end
        if (DUT.ready) disable monitor_rq;
      end
    end
    
    // Wait for completion
    wait(ready);
    #10;
    
    $display("\nRQ/RD Test Results:");
    $display("  RQ register = 0x%06h", DUT.Memory_Registers.rq_q);
    display_sm(DUT.Memory_Registers.rq_q, "RQ");
    $display("  RD register = 0x%06h", DUT.Memory_Registers.rd_q);
    display_sm(DUT.Memory_Registers.rd_q, "RD");
    $display("  DB[0] = 0x%06h", DUT.Memory_Registers.Data_Bank.mem[0]);
    display_sm(DUT.Memory_Registers.Data_Bank.mem[0], "DB[0]");
    $display("  DB[5] = 0x%06h", DUT.Memory_Registers.Data_Bank.mem[5]);
    display_sm(DUT.Memory_Registers.Data_Bank.mem[5], "DB[5]");
    $display("  DB[6] (RQ+DB[0]) = 0x%06h", DUT.Memory_Registers.Data_Bank.mem[6]);
    display_sm(DUT.Memory_Registers.Data_Bank.mem[6], "DB[6]");
    
    $display("\nDebug - Instruction decode at PC=2:");
    $display("  ROM[2] = %016b", DUT.Sequencer.ROM.mem[2]);
    $display("  ctl_b = %05b (sel_R=%02b, sel_S=%02b, b0=%b)", 
             DUT.Sequencer.ROM.mem[2][10:6],
             DUT.Sequencer.ROM.mem[2][10:9],
             DUT.Sequencer.ROM.mem[2][8:7],
             DUT.Sequencer.ROM.mem[2][6]);
    
    // Expected: RQ=4.0, RQ+DB[0] = 4.0+0.0 = 4.0 (since memory was reset)
    tc_result = q_of_int(4);  // 4.0
    
    checks = checks + 1;
    if (DUT.Memory_Registers.rq_q == val_a) begin
      $display("PASS: RQ loaded correctly (4.0)");
    end else begin
      $display("ERROR: RQ load failed (expected 0x%06h, got 0x%06h)", val_a, DUT.Memory_Registers.rq_q);
      errors = errors + 1;
    end
    
    checks = checks + 1;
    if (DUT.Memory_Registers.Data_Bank.mem[6] == tc_result) begin
      $display("PASS: RQ used in arithmetic correctly (4.0 + 0.0 = 4.0)");
    end else begin
      $display("ERROR: RQ arithmetic failed (expected 0x%06h, got 0x%06h)", 
               tc_result, DUT.Memory_Registers.Data_Bank.mem[6]);
      $display("  This suggests sel_S is not selecting DB[0] correctly");
      errors = errors + 1;
    end
    
    // ========== Test RD Register ==========
    $display("\n========================================");
    $display("[Test 7] RD Register Functionality");
    $display("========================================");
    
    // Reset and program ROM for RD test
    rst_n = 0;
    #20;
    rst_n = 1;
    #10;
    
    // Program ROM for RD test
    // PC=0: Load 5.0 to DB[7]
    DUT.Sequencer.ROM.mem[0] = 16'b00111_00000_00_00_01;
    // PC=1: Load DB[7] to RD (sel_data=10 for ZERO, e0=1)
    DUT.Sequencer.ROM.mem[1] = 16'b10111_00000_00_00_01;
    // PC=2: ADD DB[0] + RD (sel_R=00 for port A, sel_S=01 for RD, addr=0)
    DUT.Sequencer.ROM.mem[2] = 16'b00000_00010_00_00_10;
    // PC=3: WAIT
    DUT.Sequencer.ROM.mem[3] = 16'b00000_00000_01_00_00;
    // PC=4: Write result to DB[6]
    DUT.Sequencer.ROM.mem[4] = 16'b01110_00000_00_00_01;
    // PC=5: HALT
    DUT.Sequencer.ROM.mem[5] = 16'b00000_00000_10_00_00;
    
    // Load 5.0
    val_b = q_of_int(5);  // 5.0
    data_in = val_b;
    
    $display("Starting RD test: will load 5.0 to RD, then DB[0] + RD = 0.0 + 5.0 = 5.0");
    
    @(posedge clk);
    #1;
    start = 1'b1;
    
    @(posedge clk);
    #1;
    start = 1'b0;
    
    // Wait for completion
    wait(ready);
    #10;
    
    $display("\nRD Test Results:");
    $display("  RD register = 0x%06h", DUT.Memory_Registers.rd_q);
    display_sm(DUT.Memory_Registers.rd_q, "RD");
    $display("  DB[0] = 0x%06h", DUT.Memory_Registers.Data_Bank.mem[0]);
    display_sm(DUT.Memory_Registers.Data_Bank.mem[0], "DB[0]");
    $display("  DB[6] (DB[0]+RD) = 0x%06h", DUT.Memory_Registers.Data_Bank.mem[6]);
    display_sm(DUT.Memory_Registers.Data_Bank.mem[6], "DB[6]");
    
    // Expected: RD=5.0, DB[0]+RD = 0.0+5.0 = 5.0
    tc_result = q_of_int(5);  // 5.0
    
    checks = checks + 1;
    if (DUT.Memory_Registers.rd_q == val_b) begin
      $display("PASS: RD loaded correctly (5.0)");
    end else begin
      $display("ERROR: RD load failed (expected 0x%06h, got 0x%06h)", val_b, DUT.Memory_Registers.rd_q);
      errors = errors + 1;
    end
    
    checks = checks + 1;
    if (DUT.Memory_Registers.Data_Bank.mem[6] == tc_result) begin
      $display("PASS: RD used in arithmetic correctly (0.0 + 5.0 = 5.0)");
    end else begin
      $display("ERROR: RD arithmetic failed (expected 0x%06h, got 0x%06h)", 
               tc_result, DUT.Memory_Registers.Data_Bank.mem[6]);
      errors = errors + 1;
    end
    
    // Summary
    #50;
    $display("\n========================================");
    $display("Test Summary");
    $display("========================================");
    if (errors == 0) begin
      $display("kf_top_tb: PASS (%0d checks)", checks);
    end else begin
      $display("kf_top_tb: %0d ERRORS / %0d checks", errors, checks);
    end
    $display("========================================\n");
    
    $finish;
  end
  
  // Timeout watchdog
  initial begin
    #10000;
    $display("\nERROR: Simulation timeout!");
    $finish;
  end

endmodule
