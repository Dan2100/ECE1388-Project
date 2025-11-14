// -----------------------------------------------------------------------------
// au.v  -- Arithmetic Unit
// - Sign–magnitude fixed-point arithmetic.
// - Add/Sub (1-cycle), Mul (1-cycle with Q scaling), Div via reciprocal (24+1 cycles).
// - Parameters: W (word width), FRAC (# fractional bits in magnitude).
// ----------------------------------------------------------------------------- 
`timescale 1ns/1ps

// ===== reciprocal unit: q = floor( (1<<(2*FRAC)) / den ), 24-cycle successive approx
module recip_unit
#(parameter W=24, parameter FRAC=14)
(
  input              clk,
  input              start,      // pulse: begin reciprocal of 'den_mag'
  input  [W-2:0]     den_mag,    // magnitude of S (must be > 0)
  output reg [W-2:0] q_mag,      // magnitude of 1/S in same Q format
  output reg         rdy         // 1 for one cycle when q_mag valid
);
  // Long-division style: produce (W-1) quotient bits
  localparam CNTW = 8;           // enough for W-1 up to 255
  reg [CNTW-1:0]    cnt;
  reg               run;
  reg [2*FRAC+W:0]  rem;         // remainder grows as we shift
  wire [2*FRAC+W:0] rem_sub = rem - {{(2*FRAC+1){1'b0}}, den_mag, {(W-1){1'b0}}}; // align den
  // We align 'den' to LSB of remainder by placing it at bit position (W-1)

  always @(posedge clk) begin
    if (start && !run) begin
      // Initialize remainder with numerator = 1 << (2*FRAC + 1)
      // Need extra shift because we shift before first comparison
      rem   <= {{(W-2){1'b0}}, 1'b1, {(2*FRAC+1){1'b0}}}; // 1<<(2*FRAC+1)
      q_mag <= {(W-1){1'b0}};
      cnt   <= (W-1);  // 23 iterations for 23-bit magnitude
      run   <= 1'b1;
      rdy   <= 1'b0;
    end else if (run) begin
      // Shift left remainder and build quotient bit-by-bit
      rem <= {rem[2*FRAC+W-1:0], 1'b0};
      if (rem_sub[2*FRAC+W]) begin
        // subtraction would underflow => quotient bit = 0
        q_mag <= {q_mag[W-3:0], 1'b0};
      end else begin
        // subtraction ok => quotient bit = 1, commit subtraction
        rem   <= rem_sub;
        q_mag <= {q_mag[W-3:0], 1'b1};
      end
      if (cnt == 1) begin
        run <= 1'b0;
        rdy <= 1'b1;
      end else begin
        cnt <= cnt - 1;
        rdy <= 1'b0;
      end
    end else begin
      rdy <= 1'b0;
    end
  end

  // Initialize run to 0
  initial begin
    run = 1'b0;
    rdy = 1'b0;
  end
endmodule

// ===== Arithmetic Unit
module au
#(parameter W=24, parameter FRAC=14)
(
  input               clk,
  input               start,        // pulse to start operation

  // Operands from Router B (sign-magnitude)
  input  [W-1:0]      R_in,
  input  [W-1:0]      S_in,
  input  [W-1:0]      Iimm_in,      // immediate (e.g., 0, +1, -1)

  // Control
  input  [1:0]        op_sel,       // 00=ADD, 01=SUB, 10=MUL, 11=DIV(R * 1/S)
  input  [1:0]        mul_y_sel,    // 00=S_in, 01=Iimm_in, 10=inv(S), 11=reserved

  // Result / status
  output reg [W-1:0]  result,       // sign-magnitude output
  output reg          done,         // 1 when result valid (1-cycle pulse)
  output              busy          // AU busy (during reciprocal)
);

  // ---- Helpers: max magnitude (W-1 bits)
  localparam [W-2:0] MAG_MAX = {(W-1){1'b1}};

  // ---- Convert sign-magnitude to signed (two's complement) integer representation
  function [W:0] sm_to_tc; // one extra bit to avoid overflow in add/sub
    input [W-1:0] sm;
    reg   [W-2:0] mag;
    begin
      mag     = sm[W-2:0];
      sm_to_tc = sm[W-1] ? -{{1'b0}, mag} : {{1'b0}, mag};
    end
  endfunction

  // ---- Convert signed two's complement back to sign-magnitude with saturation
  function [W-1:0] tc_to_sm_sat;
    input signed [W:0] val;
    reg         sign;
    reg [W-2:0] mag;
    reg signed [W:0] absval;
    begin
      sign  = (val < 0);
      absval = sign ? -val : val;
      // saturate magnitude
      if (absval[W-1:0] > MAG_MAX) mag = MAG_MAX;
      else                         mag = absval[W-1:0];
      tc_to_sm_sat = {sign, mag};
    end
  endfunction

  // ---- Add/Sub path (1-cycle combinational, registered at output)
  wire signed [W:0] R_tc = sm_to_tc(R_in);
  wire signed [W:0] S_tc = sm_to_tc(S_in);
  wire signed [W:0] add_tc = R_tc + S_tc;
  wire signed [W:0] sub_tc = R_tc - S_tc;
  wire [W-1:0]      add_sm = tc_to_sm_sat(add_tc);
  wire [W-1:0]      sub_sm = tc_to_sm_sat(sub_tc);
  
  // Latched versions for ADD/SUB (computed after R_lat/S_lat are declared)
  wire signed [W:0] R_lat_tc, S_lat_tc, add_lat_tc, sub_lat_tc;
  wire [W-1:0] add_lat_sm, sub_lat_sm;

  // ---- Multiply path (sign-magnitude multiply with Q scaling + rounding)
  wire        sign_mul = R_in[W-1] ^ S_in[W-1];
  wire [W-2:0] R_mag   = R_in[W-2:0];
  wire [W-2:0] S_mag   = S_in[W-2:0];
  // Y input choice for multiplier: S, Iimm, or reciprocal(S)
  reg  [W-1:0] Y_sel;        // sign-magnitude
  wire [W-2:0] Y_mag   = Y_sel[W-2:0];
  wire         Y_sign  = Y_sel[W-1];
  wire         sign_mul_sel = R_in[W-1] ^ Y_sign;

  // 24x24 -> 48 product of magnitudes
  wire [2*(W-1)-1:0] prod_full = R_mag * Y_mag;

  // Q scaling: >> FRAC (truncation, no rounding for now)
  wire [W-2:0]       prod_scaled  = prod_full[2*(W-1)-1:FRAC];

  // Saturate magnitude after scaling
  wire [W-2:0] mul_mag_sat = (prod_scaled > MAG_MAX) ? MAG_MAX : prod_scaled;
  wire [W-1:0] mul_sm      = {sign_mul_sel, mul_mag_sat};

  // ---- Reciprocal unit (for DIV or MUL with inv(S))
  wire [W-2:0] recip_q_mag;
  wire         recip_rdy;
  reg          recip_start;
  reg          recip_start_reg;  // Registered version for proper timing

  recip_unit #(.W(W), .FRAC(FRAC)) Mult_Inv (
    .clk   (clk),
    .start (recip_start_reg),
    .den_mag(S_mag == { (W-1){1'b0} } ? {{(W-2){1'b1}},1'b0} : S_mag), // avoid zero: clamp to tiny
    .q_mag (recip_q_mag),
    .rdy   (recip_rdy)
  );

  // ---- FSM to manage operations and result timing
  localparam ST_IDLE   = 2'd0;
  localparam ST_SIMPLE = 2'd1; // add/sub/mul without reciprocal
  localparam ST_WAITR  = 2'd2; // waiting reciprocal
  localparam ST_MULINV = 2'd3; // multiply by reciprocal (1 cycle)

  reg [1:0] state, next_state;

  // latched operands/control across multi-cycle ops
  reg [W-1:0] R_lat, S_lat, Iimm_lat;
  reg [1:0]   op_lat, muly_lat;
  
  // Latched operand conversions for ADD/SUB
  assign R_lat_tc = sm_to_tc(R_lat);
  assign S_lat_tc = sm_to_tc(S_lat);
  assign add_lat_tc = R_lat_tc + S_lat_tc;
  assign sub_lat_tc = R_lat_tc - S_lat_tc;
  assign add_lat_sm = tc_to_sm_sat(add_lat_tc);
  assign sub_lat_sm = tc_to_sm_sat(sub_lat_tc);

  assign busy = (state == ST_WAITR);

  // Next-state logic
  always @* begin
    next_state   = state;
    recip_start  = 1'b0;

    case (state)
      ST_IDLE: begin
        if (start) begin
          if (op_sel == 2'b11 || (op_sel==2'b10 && mul_y_sel==2'b10)) begin
            // DIV or MUL using inv(S): launch reciprocal
            next_state  = ST_WAITR;
            recip_start = 1'b1;
          end else begin
            // Simple 1-cycle op: ADD/SUB/MUL with S or Iimm
            next_state  = ST_SIMPLE;
          end
        end
      end

      ST_SIMPLE: begin
        // results available this cycle, register on clk edge
        next_state = ST_IDLE;
      end

      ST_WAITR: begin
        if (recip_rdy) begin
          next_state = ST_MULINV; // multiply by reciprocal next cycle
        end
      end

      ST_MULINV: begin
        next_state = ST_IDLE;
      end
    endcase
  end

  // Operand/control latches + output register
  always @(posedge clk) begin
    if (state == ST_IDLE && start) begin
      R_lat    <= R_in;
      S_lat    <= S_in;
      Iimm_lat <= Iimm_in;
      op_lat   <= op_sel;
      muly_lat <= mul_y_sel;
    end
  end

  // Select Y source for multiplier based on current phase
  always @* begin
    case (state)
      ST_SIMPLE: begin
        case (op_lat==2'b10 ? muly_lat : 2'b00) // if MUL select Y, else ignore
          2'b01: Y_sel = Iimm_lat;
          2'b10: Y_sel = {S_lat[W-1], recip_q_mag}; // reciprocal with S's sign
          default: Y_sel = S_lat;
        endcase
      end
      ST_MULINV: begin
        Y_sel = {S_lat[W-1], recip_q_mag}; // use reciprocal magnitude with S's sign
      end
      default: begin
        // when idle/wait, default to S input (doesn't matter)
        Y_sel = S_in;
      end
    endcase
  end

  // Register the result on done cycles
  always @(posedge clk) begin
    case (state)
      ST_SIMPLE: begin
        case (op_lat)
          2'b00: result <= add_lat_sm;    // ADD (uses latched operands)
          2'b01: result <= sub_lat_sm;    // SUB (uses latched operands)
          2'b10: result <= mul_sm;        // MUL (Y per muly_lat)
          default: result <= {1'b0, {(W-1){1'b0}}};
        endcase
      end
      ST_MULINV: begin
        result <= mul_sm;             // multiply (R_lat * inv(S_lat))
      end
    endcase
  end

  // State register and done signal
  always @(posedge clk) begin
    state <= next_state;
    // Pulse done high when in completion states
    done <= (state == ST_SIMPLE || state == ST_MULINV);
    // Register recip_start for proper timing
    recip_start_reg <= recip_start;
  end

  // Reset-less FSM start state
  initial begin
    state = ST_IDLE;
    done = 1'b0;
    recip_start_reg = 1'b0;
  end

endmodule
