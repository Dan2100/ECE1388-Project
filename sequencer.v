// -----------------------------------------------------------------------------
// sequencer.v
// - 8-bit PC driving a 256x16 ROM
// - START begins execution at PC=0; READY=1 when idle
// - ctl_c[1:0] controls flow: 00=INC, 01=WAIT(for continue), 10=HALT, 11=INC
// - ROM has a simple write port for TB programming
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

// 256x16 ROM with simple write port (for TB/programming)
module rom_256x16 (
  input              clk,
  input      [7:0]   addr,
  output     [15:0]  dout,
  // programming port
  input              prog_we,
  input      [7:0]   prog_addr,
  input      [15:0]  prog_data
);
  reg [15:0] mem [0:255];
  assign dout = mem[addr];

  always @(posedge clk) begin
    if (prog_we)
      mem[prog_addr] <= prog_data;
  end
  
  // Initialize ROM with test program following documented instruction format
  // See INSTRUCTION_FORMAT.md for details
  // Format: a4-a0 | b4-b0 | c1-c0 | d1-d0 | e1-e0
  integer i;
  initial begin
    // Default all instructions to HALT (c1c0=10)
    for (i = 0; i < 256; i = i + 1) begin
      mem[i] = 16'b00000_00000_10_00_00;  // HALT
    end
    
    // Test Program: Load two values, perform ADD/SUB/MUL
    // Assumes testbench provides data_in at appropriate times
    
    // PC=0: Write DATA_IN to DB[0]
    // a4-a0=00000 (DATA_IN, addr=0), c1c0=00 (INC), e0=1 (WRITE)
    mem[0] = 16'b00000_00000_00_00_01;  // Load to addr 0
    
    // PC=1: Write DATA_IN to DB[1]  
    // a4-a0=00001 (DATA_IN, addr=1), c1c0=00 (INC), e0=1 (WRITE)
    mem[1] = 16'b00001_00000_00_00_01;  // Load to addr 1
    
    // PC=2: ADD operation - Read DB[0] (port A) and DB[1] (port B), start AU
    // a4-a0=00000 (addr_a=0), b4-b0=00001 (R=A, S=B, b0=1 means addr_b=addr_a+1)
    // c1c0=00 (INC), d1d0=00 (ADD), e1=1 (START)
    mem[2] = 16'b00000_00001_00_00_10;
    
    // PC=3: WAIT for AU done
    // c1c0=01 (WAIT)
    mem[3] = 16'b00000_00000_01_00_00;
    
    // PC=4: Write RESULT to DB[2]
    // a4-a0=01010 (RESULT, addr=2), c1c0=00 (INC), e0=1 (WRITE)
    mem[4] = 16'b01010_00000_00_00_01;
    
    // PC=5: SUB operation - DB[0] - DB[1]
    // a4-a0=00000, b4-b0=00001 (b0=1 for addr_b=addr_a+1), d1d0=01 (SUB), e1=1
    mem[5] = 16'b00000_00001_00_01_10;
    
    // PC=6: WAIT for AU done
    mem[6] = 16'b00000_00000_01_00_00;
    
    // PC=7: Write RESULT to DB[3]
    // a4-a0=01011 (RESULT, addr=3)
    mem[7] = 16'b01011_00000_00_00_01;
    
    // PC=8: MUL operation - DB[0] * DB[1]
    // d1d0=10 (MUL), b0=1 for different addresses
    mem[8] = 16'b00000_00001_00_10_10;
    
    // PC=9: WAIT
    mem[9] = 16'b00000_00000_01_00_00;
    
    // PC=10: Write RESULT to DB[4]
    // a4-a0=01100 (RESULT, addr=4)
    mem[10] = 16'b01100_00000_00_00_01;
    
    // PC=11: HALT
    mem[11] = 16'b00000_00000_10_00_00;
  end
endmodule

module sequencer (
  input             clk,
  input             rst_n,      // synchronous active-low reset (paper uses active-high RESET)
  input             start,      // 1-cycle pulse to start a run
  input             continue_i, // from AU (e.g., operation done signal)

  // ROM programming (for testbench/ease of use)
  input             rom_we,
  input      [7:0]  rom_waddr,
  input      [15:0] rom_wdata,

  // Decoded control fields to the rest of the datapath
  output     [4:0]  ctl_a,
  output     [4:0]  ctl_b,
  output     [1:0]  ctl_c,
  output     [1:0]  ctl_d,
  output     [1:0]  ctl_e,

  // Status
  output reg        ready,      // high when idle (paper: READY)
  output     [7:0]  pc_dbg      // (optional) observe current PC
);
  // Run/idle FF
  reg running;

  // 8-bit PC
  reg [7:0] pc;

  // ROM
  wire [15:0] instr;
  rom_256x16 ROM (
    .clk(clk),
    .addr(pc),
    .dout(instr),
    .prog_we(rom_we),
    .prog_addr(rom_waddr),
    .prog_data(rom_wdata)
  );

  // Decode fields (always decode current ROM output)
  assign ctl_a = instr[15:11];
  assign ctl_b = instr[10:6];
  assign ctl_c = instr[5:4];
  assign ctl_d = instr[3:2];
  assign ctl_e = instr[1:0];

  assign pc_dbg = pc;

  // PC increment logic per paper:
  // - ctl_c[1:0]: 00=INC (1-cycle ops), 01=WAIT (multi-cycle), 10=HALT, 11=reserved
  // - PC increments when operation completes
  // - For WAIT: increment when continue_i=1 (operation done signal from AU)
  // - For HALT: stop incrementing, set READY=1
  
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset: READY=1, PC initialized
      ready <= 1'b1;
      pc    <= 8'd0;
    end else if (ready) begin
      // Idle state - wait for START
      if (start) begin
        // START signal: go to address 0, begin execution, clear READY
        ready <= 1'b0;
        pc    <= 8'd0;
      end
    end else begin
      // Running state: decode ctl_c to control PC
      case (ctl_c)
        2'b00: begin
          // Normal increment: 1-cycle operation (ADD/SUB/MUL)
          pc <= pc + 8'd1;
        end
        2'b01: begin
          // WAIT: multi-cycle operation (DIV/inverse)
          // PC increments only when continue_i=1 (operation done)
          if (continue_i) begin
            pc <= pc + 8'd1;
          end
          // else: hold PC at current value
        end
        2'b10: begin
          // HALT: stop execution, set READY=1, PC freezes
          ready <= 1'b1;
        end
        2'b11: begin
          // Reserved/unused: treat as normal increment
          pc <= pc + 8'd1;
        end
      endcase
    end
  end

  // Initialize ready to 1
  initial begin
    ready = 1'b1;
  end

endmodule
