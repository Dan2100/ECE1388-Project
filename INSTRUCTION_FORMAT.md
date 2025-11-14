# Instruction Format for Kalman Filter ASIC

## Overview
16-bit instruction format: `a4 a3 a2 a1 a0 b4 b3 b2 b1 b0 c1 c0 d1 d0 e1 e0`

## Control Bit Mapping

### Field A (bits 15-11): Router A / Memory Control
- **a4-a3**: Data source selection (sel_data)
  - `00`: External DATA_IN
  - `01`: AU RESULT
  - `10`: ZERO
  - `11`: Reserved
- **a2-a0**: Memory address (3 bits = 0-7 addresses, expandable)

### Field B (bits 10-6): Router B / Operand Selection
- **b4-b3**: R operand selection (sel_R)
  - `00`: Data from port A (DB[addr_a])
  - `01`: RQ register
  - `10`: Zero
  - `11`: All ones (0xFFFFFF)
- **b2-b1**: S operand selection (sel_S)
  - `00`: Data from port B (DB[addr_b])
  - `01`: RD register
  - `10`: Zero
  - `11`: All ones (0xFFFFFF)
- **b0**: Address control
  - `0`: Use addr from field A for both ports
  - `1`: Use separate address (would need additional encoding)

### Field C (bits 5-4): Sequencer Control
- **c1-c0**: PC control (requires decoder per paper)
  - `00`: INCREMENT - Continue to next instruction
  - `01`: WAIT - Wait for AU done (continue_i signal)
  - `10`: HALT - Stop execution, set READY=1
  - `11`: Reserved

### Field D (bits 3-2): AU Operation
- **d1-d0**: Operation selection (op_sel)
  - `00`: ADD (R + S)
  - `01`: SUB (R - S)
  - `10`: MUL (R * S)
  - `11`: DIV (R / S, using multiplicative inverse)

### Field E (bits 1-0): Execution Control
- **e1**: AU start signal
  - `1`: Start AU operation
  - `0`: No operation
- **e0**: Memory write enable
  - `1`: Write data to memory at address specified in field A
  - `0`: No write

## Instruction Examples

### Load immediate value to DB[0]
```
Bits: 00000_00000_00_00_01
      a4-a0 b4-b0 c1c0 d1d0 e1e0
      ^^^^^       ^^^^      ^^
      DATA_IN     INC       WR
      addr=0
Hex: 0x0001
```

### ADD DB[0] + DB[1], start AU
```
Bits: 00000_00010_00_00_10
      ^^^^^       ^^^^    ^^
      addr=0      INC  ADD START
      sel_R=A
      sel_S=B(addr=1)
Hex: 0x0082
```

### Wait for AU completion
```
Bits: xxxxx_xxxxx_01_xx_00
                  ^^^^
                  WAIT
Hex: 0x0010 (plus other bits)
```

### Write AU result to DB[2]
```
Bits: 01010_00000_00_00_01
      ^^^^^       ^^^^    ^^
      RESULT      INC     WR
      addr=2
Hex: 0x5001
```

### HALT execution
```
Bits: xxxxx_xxxxx_10_xx_xx
                  ^^^^
                  HALT
Hex: 0x0028 (plus other bits)
```

## Notes
- For multi-cycle operations (DIV), must use WAIT instruction after starting
- Memory has dual-port read, single-port write
- AU operations complete in 1 cycle (ADD/SUB/MUL) or 24 cycles (DIV)
- This encoding may differ from the paper's actual implementation
