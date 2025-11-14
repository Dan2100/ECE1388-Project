// -----------------------------------------------------------------------------
// kf_1d_tb.v
// Simple 1D Kalman Filter Test
// 
// 1D KF equations (scalar):
//   Time Update:    x⁻ = Φ·x,  P⁻ = Φ·P·Φ + Q
//   Measurement:    K = P⁻/(P⁻+R)
//                   x̂ = x⁻ + K·(y-x⁻)
//                   P = (1-K)·P⁻
//
// Memory Layout:
//   DB[0] = x   (state estimate)
//   DB[1] = P   (error covariance)
//   DB[2] = Φ   (state transition, constant = 1.0)
//   DB[3] = Q   (process noise, constant = 0.01)
//   DB[4] = R   (measurement noise, constant = 0.1)
//   DB[5] = y   (measurement, updated each iteration)
//   DB[6] = temp for calculations
//   DB[7] = temp for calculations
//
// This test will:
// 1. Initialize constants (Φ=1.0, Q=0.01, R=0.1)
// 2. Initialize x=0, P=1.0
// 3. Provide measurement y
// 4. Execute one KF iteration
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module kf_1d_tb();
  parameter W=24;
  parameter FRAC=14;
  
  reg clk, rst_n, start;
  reg [W-1:0] data_in;
  wire ready, au_done;
  wire [W-1:0] result_out;
  
  // Instantiate DUT
  kf_top #(.W(W), .FRAC(FRAC)) dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .data_in(data_in),
    .ready(ready),
    .result_out(result_out),
    .au_done(au_done)
  );
  
  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;
  
  // Helper function: convert real to sign-magnitude S9.14
  function [W-1:0] real_to_sm;
    input real x;
    reg sign;
    integer mag_int;
    reg [W-2:0] mag;
    begin
      sign = (x < 0.0);
      mag_int = (sign ? -x : x) * (1 << FRAC);
      mag = mag_int[W-2:0];
      real_to_sm = {sign, mag};
    end
  endfunction
  
  // Helper function: convert sign-magnitude to real
  function real sm_to_real;
    input [W-1:0] sm;
    reg sign;
    reg [W-2:0] mag;
    real val;
    begin
      sign = sm[W-1];
      mag = sm[W-2:0];
      val = $itor(mag) / (1 << FRAC);
      sm_to_real = sign ? -val : val;
    end
  endfunction
  
  // ROM programming task
  task program_rom;
    integer pc;
    begin
      // Initialize all to HALT
      for (pc = 0; pc < 256; pc = pc + 1) begin
        dut.Sequencer.ROM.mem[pc] = 16'b00000_00000_10_00_00;
      end
      
      // ==== INITIALIZATION PHASE ====
      // Load constants: Φ, Q, R
      // Load initial state: x=0, P=1.0
      
      pc = 0;
      
      // PC=0: Load Phi=1.0 to DB[2]
      dut.Sequencer.ROM.mem[pc] = 16'b00010_00000_00_00_01; // DATA_IN->DB[2], WR
      pc = pc + 1;
      
      // PC=1: Load Q=0.01 to DB[3]
      dut.Sequencer.ROM.mem[pc] = 16'b00011_00000_00_00_01; // DATA_IN->DB[3], WR
      pc = pc + 1;
      
      // PC=2: Load R=0.1 to DB[4]
      dut.Sequencer.ROM.mem[pc] = 16'b00100_00000_00_00_01; // DATA_IN->DB[4], WR
      pc = pc + 1;
      
      // PC=3: Load x=0 to DB[0]
      dut.Sequencer.ROM.mem[pc] = 16'b00000_00000_00_00_01; // DATA_IN->DB[0], WR
      pc = pc + 1;
      
      // PC=4: Load P=1.0 to DB[1]
      dut.Sequencer.ROM.mem[pc] = 16'b00001_00000_00_00_01; // DATA_IN->DB[1], WR
      pc = pc + 1;
      
      // PC=5: Load measurement y to DB[5]
      dut.Sequencer.ROM.mem[pc] = 16'b00101_00000_00_00_01; // DATA_IN->DB[5], WR
      pc = pc + 1;
      
      // ==== KALMAN FILTER ALGORITHM ====
      // Time Update:
      //   x⁻ = Φ·x  (Φ=1, so x⁻=x, skip for now, could implement later)
      //   P⁻ = Φ·P·Φ + Q = P + Q (since Φ=1)
      
      // PC=6: P⁻ = P + Q (DB[1] + DB[3] → RQ)
      // Load P to RQ first
      dut.Sequencer.ROM.mem[pc] = 16'b00001_00000_00_00_11; // DB[1]→RQ (e1e0=11)
      pc = pc + 1;
      
      // PC=7: ADD RQ + DB[3] (P + Q)
      // sel_R=01(RQ), sel_S=00(B_data), addr_a=3
      dut.Sequencer.ROM.mem[pc] = 16'b00011_01000_00_00_10; // RQ+DB[3], ADD, START
      pc = pc + 1;
      
      // PC=8: WAIT
      dut.Sequencer.ROM.mem[pc] = 16'b00000_00000_01_00_00; // WAIT
      pc = pc + 1;
      
      // PC=9: Write result to DB[6] (P⁻ temp)
      dut.Sequencer.ROM.mem[pc] = 16'b01110_00000_00_00_01; // RESULT→DB[6], WR
      pc = pc + 1;
      
      // Measurement Update:
      //   K = P⁻/(P⁻+R)
      //   First compute P⁻+R
      
      // PC=10: Load P⁻ to RQ
      dut.Sequencer.ROM.mem[pc] = 16'b00110_00000_00_00_11; // DB[6]→RQ
      pc = pc + 1;
      
      // PC=11: ADD RQ + DB[4] (P⁻ + R)
      dut.Sequencer.ROM.mem[pc] = 16'b00100_01000_00_00_10; // RQ+DB[4], ADD, START
      pc = pc + 1;
      
      // PC=12: WAIT
      dut.Sequencer.ROM.mem[pc] = 16'b00000_00000_01_00_00; // WAIT
      pc = pc + 1;
      
      // PC=13: Write to DB[7] (P⁻+R temp)
      dut.Sequencer.ROM.mem[pc] = 16'b01111_00000_00_00_01; // RESULT→DB[7], WR
      pc = pc + 1;
      
      // PC=14: K = P⁻ / (P⁻+R) = DB[6]/DB[7]
      // Load DB[6] to RQ
      dut.Sequencer.ROM.mem[pc] = 16'b00110_00000_00_00_11; // DB[6]→RQ
      pc = pc + 1;
      
      // PC=15: DIV RQ / DB[7]
      dut.Sequencer.ROM.mem[pc] = 16'b00111_01000_00_11_10; // RQ/DB[7], DIV, START
      pc = pc + 1;
      
      // PC=16: WAIT for DIV (24 cycles)
      dut.Sequencer.ROM.mem[pc] = 16'b00000_00000_01_00_00; // WAIT
      pc = pc + 1;
      
      // PC=17: Write K to DB[6] (reuse temp)
      dut.Sequencer.ROM.mem[pc] = 16'b01110_00000_00_00_01; // RESULT→DB[6], WR
      pc = pc + 1;
      
      // Innovation: (y - x⁻) = y - x (since x⁻=x for Φ=1)
      // PC=18: Load y to RQ
      dut.Sequencer.ROM.mem[pc] = 16'b00101_00000_00_00_11; // DB[5]→RQ
      pc = pc + 1;
      
      // PC=19: SUB RQ - DB[0] (y - x)
      dut.Sequencer.ROM.mem[pc] = 16'b00000_01000_00_01_10; // RQ-DB[0], SUB, START
      pc = pc + 1;
      
      // PC=20: WAIT
      dut.Sequencer.ROM.mem[pc] = 16'b00000_00000_01_00_00; // WAIT
      pc = pc + 1;
      
      // PC=21: Write innovation to DB[7]
      dut.Sequencer.ROM.mem[pc] = 16'b01111_00000_00_00_01; // RESULT→DB[7], WR
      pc = pc + 1;
      
      // x̂ = x + K·(y-x)
      // First: K·(y-x) = DB[6]·DB[7]
      // PC=22: Load K to RQ
      dut.Sequencer.ROM.mem[pc] = 16'b00110_00000_00_00_11; // DB[6]→RQ
      pc = pc + 1;
      
      // PC=23: MUL RQ × DB[7]
      dut.Sequencer.ROM.mem[pc] = 16'b00111_01000_00_10_10; // RQ×DB[7], MUL, START
      pc = pc + 1;
      
      // PC=24: WAIT
      dut.Sequencer.ROM.mem[pc] = 16'b00000_00000_01_00_00; // WAIT
      pc = pc + 1;
      
      // PC=25: Write K·innovation to DB[7]
      dut.Sequencer.ROM.mem[pc] = 16'b01111_00000_00_00_01; // RESULT→DB[7], WR
      pc = pc + 1;
      
      // PC=26: x̂ = x + K·innovation
      // Load x to RQ
      dut.Sequencer.ROM.mem[pc] = 16'b00000_00000_00_00_11; // DB[0]→RQ
      pc = pc + 1;
      
      // PC=27: ADD RQ + DB[7]
      dut.Sequencer.ROM.mem[pc] = 16'b00111_01000_00_00_10; // RQ+DB[7], ADD, START
      pc = pc + 1;
      
      // PC=28: WAIT
      dut.Sequencer.ROM.mem[pc] = 16'b00000_00000_01_00_00; // WAIT
      pc = pc + 1;
      
      // PC=29: Write x̂ to DB[0] (update state)
      dut.Sequencer.ROM.mem[pc] = 16'b01000_00000_00_00_01; // RESULT→DB[0], WR
      pc = pc + 1;
      
      // P = (1-K)·P⁻
      // First: 1-K
      // PC=30: Load 1.0 to RQ (need to provide via DATA_IN or use constant)
      // For now, skip P update and just HALT
      // TODO: Implement P update
      
      // PC=30: HALT
      dut.Sequencer.ROM.mem[pc] = 16'b00000_00000_10_00_00; // HALT
      
      $display("[ROM] Programmed 1D Kalman Filter with %0d instructions", pc+1);
    end
  endtask
  
  // Main test
  initial begin
    $display("=== 1D Kalman Filter Test ===");
    
    // Initialize
    rst_n = 0;
    start = 0;
    data_in = 0;
    
    program_rom();
    
    // Reset
    repeat(2) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);
    
    // Load constants
    $display("\n[T=%0t] Loading constants...", $time);
    
    // Φ = 1.0
    data_in = real_to_sm(1.0);
    $display("  Φ = 1.0 (0x%06h)", data_in);
    start = 1;
    @(posedge clk);
    start = 0;
    @(posedge clk);
    
    // Q = 0.01
    data_in = real_to_sm(0.01);
    $display("  Q = 0.01 (0x%06h)", data_in);
    @(posedge clk);
    
    // R = 0.1
    data_in = real_to_sm(0.1);
    $display("  R = 0.1 (0x%06h)", data_in);
    @(posedge clk);
    
    // x = 0.0
    data_in = real_to_sm(0.0);
    $display("  x = 0.0 (0x%06h)", data_in);
    @(posedge clk);
    
    // P = 1.0
    data_in = real_to_sm(1.0);
    $display("  P = 1.0 (0x%06h)", data_in);
    @(posedge clk);
    
    // y = 2.5 (measurement)
    data_in = real_to_sm(2.5);
    $display("  y = 2.5 (0x%06h)", data_in);
    @(posedge clk);
    
    // Wait for ready
    $display("\n[T=%0t] Waiting for KF to complete...", $time);
    wait(ready);
    $display("[T=%0t] KF computation done!", $time);
    
    // Read results from memory
    $display("\n=== Results ===");
    $display("  x̂ (DB[0]) = %f (0x%06h)", sm_to_real(dut.Memory_Registers.Data_Bank.mem[0]), dut.Memory_Registers.Data_Bank.mem[0]);
    $display("  P (DB[1]) = %f (0x%06h)", sm_to_real(dut.Memory_Registers.Data_Bank.mem[1]), dut.Memory_Registers.Data_Bank.mem[1]);
    $display("  P⁻ (DB[6]) = %f (0x%06h)", sm_to_real(dut.Memory_Registers.Data_Bank.mem[6]), dut.Memory_Registers.Data_Bank.mem[6]);
    $display("  K (reused) = %f (0x%06h)", sm_to_real(dut.Memory_Registers.Data_Bank.mem[6]), dut.Memory_Registers.Data_Bank.mem[6]);
    
    // Expected result for first iteration:
    // x⁻ = 0, P⁻ = 1.01
    // K = 1.01/(1.01+0.1) = 1.01/1.11 ≈ 0.9099
    // x̂ = 0 + 0.9099×(2.5-0) ≈ 2.275
    $display("\n=== Expected (manual calculation) ===");
    $display("  P⁻ = P+Q = 1.0+0.01 = 1.01");
    $display("  K = P⁻/(P⁻+R) = 1.01/1.11 ≈ 0.9099");
    $display("  x̂ = x + K(y-x) = 0 + 0.9099×2.5 ≈ 2.275");
    
    $display("\n=== Test Complete ===");
    $finish;
  end
  
  // Timeout
  initial begin
    #100000;
    $display("ERROR: Timeout!");
    $finish;
  end
  
endmodule
