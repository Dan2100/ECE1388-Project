module sequencer (
    input clk,
    input start,
    input reset,
    input cont,
    output ready,
    output [4:0] ctl_a,
    output [4:0] ctl_b,
    output [1:0] ctl_c,
    output [1:0] ctl_d,
    output ctl_e,
    output ctl_f,
    input p,
    input [7:0] addr,
    input [15:0] ctl
);
    wire [7:0] pc_inc;
    wire [7:0] pc_set;
    wire [7:0] pc_in;
    wire [7:0] pc_out;
    wire pc_mux_sel;
    wire seq_reg_q;
    wire seq_reg_set;

    assign seq_reg_set = (~(&ctl_c)) | reset;

    assign ready = seq_reg_q;

    assign pc_in = (cont|seq_reg_q) ? pc_set : pc_inc;

    assign pc_inc = pc_out + 8'b1;

    assign pc_set = (seq_reg_set) ? 8'b0 : pc_out;

    seq_reg r0 (.clk(clk), .set(seq_reg_set), .clear(start), .q(seq_reg_q));
    pc_reg r_pc (.clk(clk), .w(cont), .din(pc_in), .q(pc_out));

    control_word ctl_words (.dir(pc_out), .dout({ctl_a, ctl_b, ctl_c, ctl_d, ctl_e, ctl_f}), .p(p), .addr(addr), .ctl(ctl));

endmodule

module pc_reg (
    input clk,
    input w,
    input [7:0] din,
    output [7:0] q
);
    reg [7:0] reg_q;
    always @(posedge clk) begin
        if (w)
            reg_q <= din;
        else
            reg_q <= q;
    end
    assign q = reg_q;
endmodule

module seq_reg (
    input set,
    input clear,
    input clk,
    output q
);
    reg reg_q;
    always @(posedge clk) begin
        if (clear)
            reg_q <= 0;
        else if (set)
            reg_q <= 1;
    end
    assign q = reg_q;
endmodule

module control_word (
    input [7:0] dir,
    output [15:0] dout,
    input p,
    input [7:0] addr,
    input [15:0] ctl
);
    wire [15:0] q [0:255];
    genvar i;
    generate
        for (i=0; i<256; i=i+1) begin: gen_latches
            latch_16 u_latch (.p(addr==i[7:0] & p), .ctl(ctl), .word(q[i]));
        end
    endgenerate
    assign dout = q[dir];
endmodule

module latch_16 (
    input p,
    input [15:0] ctl,
    output [15:0] word
);
    reg [15:0] data;
    always @(*) begin
        if (p)
            data <= ctl;
        else
            data <= data;
    end
    assign word = data;
endmodule

module ROM (
    input [7:0] dir,
    output [15:0] dout
);
    reg [15:0] data;

    assign dout = data;

    always @(*) begin
        case (dir)
            8'h00: data = 16'h0000;
            8'h01: data = 16'h0001;
            8'h02: data = 16'h0002;
            8'h03: data = 16'h0003;
            8'h04: data = 16'h0004;
            8'h05: data = 16'h0005;
            8'h06: data = 16'h0006;
            8'h07: data = 16'h0007;
            8'h08: data = 16'h0008;
            8'h09: data = 16'h0009;
            8'h0A: data = 16'h000A;
            8'h0B: data = 16'h000B;
            8'h0C: data = 16'h000C;
            8'h0D: data = 16'h000D;
            8'h0E: data = 16'h000E;
            8'h0F: data = 16'h000F;
            8'h10: data = 16'h0010;
            8'h11: data = 16'h0011;
            8'h12: data = 16'h0012;
            8'h13: data = 16'h0013;
            8'h14: data = 16'h0014;
            8'h15: data = 16'h0015;
            8'h16: data = 16'h0016;
            8'h17: data = 16'h0017;
            8'h18: data = 16'h0018;
            8'h19: data = 16'h0019;
            8'h1A: data = 16'h001A;
            8'h1B: data = 16'h001B;
            8'h1C: data = 16'h001C;
            8'h1D: data = 16'h001D;
            8'h1E: data = 16'h001E;
            8'h1F: data = 16'h001F;
            8'h20: data = 16'h0020;
            8'h21: data = 16'h0021;
            8'h22: data = 16'h0022;
            8'h23: data = 16'h0023;
            8'h24: data = 16'h0024;
            8'h25: data = 16'h0025;
            8'h26: data = 16'h0026;
            8'h27: data = 16'h0027;
            8'h28: data = 16'h0028;
            8'h29: data = 16'h0029;
            8'h2A: data = 16'h002A;
            8'h2B: data = 16'h002B;
            8'h2C: data = 16'h002C;
            8'h2D: data = 16'h002D;
            8'h2E: data = 16'h002E;
            8'h2F: data = 16'h002F;
            8'h30: data = 16'h0030;
            8'h31: data = 16'h0031;
            8'h32: data = 16'h0032;
            8'h33: data = 16'h0033;
            8'h34: data = 16'h0034;
            8'h35: data = 16'h0035;
            8'h36: data = 16'h0036;
            8'h37: data = 16'h0037;
            8'h38: data = 16'h0038;
            8'h39: data = 16'h0039;
            8'h3A: data = 16'h003A;
            8'h3B: data = 16'h003B;
            8'h3C: data = 16'h003C;
            8'h3D: data = 16'h003D;
            8'h3E: data = 16'h003E;
            8'h3F: data = 16'h003F;
            8'h40: data = 16'h0040;
            8'h41: data = 16'h0041;
            8'h42: data = 16'h0042;
            8'h43: data = 16'h0043;
            8'h44: data = 16'h0044;
            8'h45: data = 16'h0045;
            8'h46: data = 16'h0046;
            8'h47: data = 16'h0047;
            8'h48: data = 16'h0048;
            8'h49: data = 16'h0049;
            8'h4A: data = 16'h004A;
            8'h4B: data = 16'h004B;
            8'h4C: data = 16'h004C;
            8'h4D: data = 16'h004D;
            8'h4E: data = 16'h004E;
            8'h4F: data = 16'h004F;
            8'h50: data = 16'h0050;
            8'h51: data = 16'h0051;
            8'h52: data = 16'h0052;
            8'h53: data = 16'h0053;
            8'h54: data = 16'h0054;
            8'h55: data = 16'h0055;
            8'h56: data = 16'h0056;
            8'h57: data = 16'h0057;
            8'h58: data = 16'h0058;
            8'h59: data = 16'h0059;
            8'h5A: data = 16'h005A;
            8'h5B: data = 16'h005B;
            8'h5C: data = 16'h005C;
            8'h5D: data = 16'h005D;
            8'h5E: data = 16'h005E;
            8'h5F: data = 16'h005F;
            8'h60: data = 16'h0060;
            8'h61: data = 16'h0061;
            8'h62: data = 16'h0062;
            8'h63: data = 16'h0063;
            8'h64: data = 16'h0064;
            8'h65: data = 16'h0065;
            8'h66: data = 16'h0066;
            8'h67: data = 16'h0067;
            8'h68: data = 16'h0068;
            8'h69: data = 16'h0069;
            8'h6A: data = 16'h006A;
            8'h6B: data = 16'h006B;
            8'h6C: data = 16'h006C;
            8'h6D: data = 16'h006D;
            8'h6E: data = 16'h006E;
            8'h6F: data = 16'h006F;
            8'h70: data = 16'h0070;
            8'h71: data = 16'h0071;
            8'h72: data = 16'h0072;
            8'h73: data = 16'h0073;
            8'h74: data = 16'h0074;
            8'h75: data = 16'h0075;
            8'h76: data = 16'h0076;
            8'h77: data = 16'h0077;
            8'h78: data = 16'h0078;
            8'h79: data = 16'h0079;
            8'h7A: data = 16'h007A;
            8'h7B: data = 16'h007B;
            8'h7C: data = 16'h007C;
            8'h7D: data = 16'h007D;
            8'h7E: data = 16'h007E;
            8'h7F: data = 16'h007F;
            8'h80: data = 16'h0080;
            8'h81: data = 16'h0081;
            8'h82: data = 16'h0082;
            8'h83: data = 16'h0083;
            8'h84: data = 16'h0084;
            8'h85: data = 16'h0085;
            8'h86: data = 16'h0086;
            8'h87: data = 16'h0087;
            8'h88: data = 16'h0088;
            8'h89: data = 16'h0089;
            8'h8A: data = 16'h008A;
            8'h8B: data = 16'h008B;
            8'h8C: data = 16'h008C;
            8'h8D: data = 16'h008D;
            8'h8E: data = 16'h008E;
            8'h8F: data = 16'h008F;
            8'h90: data = 16'h0090;
            8'h91: data = 16'h0091;
            8'h92: data = 16'h0092;
            8'h93: data = 16'h0093;
            8'h94: data = 16'h0094;
            8'h95: data = 16'h0095;
            8'h96: data = 16'h0096;
            8'h97: data = 16'h0097;
            8'h98: data = 16'h0098;
            8'h99: data = 16'h0099;
            8'h9A: data = 16'h009A;
            8'h9B: data = 16'h009B;
            8'h9C: data = 16'h009C;
            8'h9D: data = 16'h009D;
            8'h9E: data = 16'h009E;
            8'h9F: data = 16'h009F;
            8'hA0: data = 16'h00A0;
            8'hA1: data = 16'h00A1;
            8'hA2: data = 16'h00A2;
            8'hA3: data = 16'h00A3;
            8'hA4: data = 16'h00A4;
            8'hA5: data = 16'h00A5;
            8'hA6: data = 16'h00A6;
            8'hA7: data = 16'h00A7;
            8'hA8: data = 16'h00A8;
            8'hA9: data = 16'h00A9;
            8'hAA: data = 16'h00AA;
            8'hAB: data = 16'h00AB;
            8'hAC: data = 16'h00AC;
            8'hAD: data = 16'h00AD;
            8'hAE: data = 16'h00AE;
            8'hAF: data = 16'h00AF;
            8'hB0: data = 16'h00B0;
            8'hB1: data = 16'h00B1;
            8'hB2: data = 16'h00B2;
            8'hB3: data = 16'h00B3;
            8'hB4: data = 16'h00B4;
            8'hB5: data = 16'h00B5;
            8'hB6: data = 16'h00B6;
            8'hB7: data = 16'h00B7;
            8'hB8: data = 16'h00B8;
            8'hB9: data = 16'h00B9;
            8'hBA: data = 16'h00BA;
            8'hBB: data = 16'h00BB;
            8'hBC: data = 16'h00BC;
            8'hBD: data = 16'h00BD;
            8'hBE: data = 16'h00BE;
            8'hBF: data = 16'h00BF;
            8'hC0: data = 16'h00C0;
            8'hC1: data = 16'h00C1;
            8'hC2: data = 16'h00C2;
            8'hC3: data = 16'h00C3;
            8'hC4: data = 16'h00C4;
            8'hC5: data = 16'h00C5;
            8'hC6: data = 16'h00C6;
            8'hC7: data = 16'h00C7;
            8'hC8: data = 16'h00C8;
            8'hC9: data = 16'h00C9;
            8'hCA: data = 16'h00CA;
            8'hCB: data = 16'h00CB;
            8'hCC: data = 16'h00CC;
            8'hCD: data = 16'h00CD;
            8'hCE: data = 16'h00CE;
            8'hCF: data = 16'h00CF;
            8'hD0: data = 16'h00D0;
            8'hD1: data = 16'h00D1;
            8'hD2: data = 16'h00D2;
            8'hD3: data = 16'h00D3;
            8'hD4: data = 16'h00D4;
            8'hD5: data = 16'h00D5;
            8'hD6: data = 16'h00D6;
            8'hD7: data = 16'h00D7;
            8'hD8: data = 16'h00D8;
            8'hD9: data = 16'h00D9;
            8'hDA: data = 16'h00DA;
            8'hDB: data = 16'h00DB;
            8'hDC: data = 16'h00DC;
            8'hDD: data = 16'h00DD;
            8'hDE: data = 16'h00DE;
            8'hDF: data = 16'h00DF;
            8'hE0: data = 16'h00E0;
            8'hE1: data = 16'h00E1;
            8'hE2: data = 16'h00E2;
            8'hE3: data = 16'h00E3;
            8'hE4: data = 16'h00E4;
            8'hE5: data = 16'h00E5;
            8'hE6: data = 16'h00E6;
            8'hE7: data = 16'h00E7;
            8'hE8: data = 16'h00E8;
            8'hE9: data = 16'h00E9;
            8'hEA: data = 16'h00EA;
            8'hEB: data = 16'h00EB;
            8'hEC: data = 16'h00EC;
            8'hED: data = 16'h00ED;
            8'hEE: data = 16'h00EE;
            8'hEF: data = 16'h00EF;
            8'hF0: data = 16'h00F0;
            8'hF1: data = 16'h00F1;
            8'hF2: data = 16'h00F2;
            8'hF3: data = 16'h00F3;
            8'hF4: data = 16'h00F4;
            8'hF5: data = 16'h00F5;
            8'hF6: data = 16'h00F6;
            8'hF7: data = 16'h00F7;
            8'hF8: data = 16'h00F8;
            8'hF9: data = 16'h00F9;
            8'hFA: data = 16'h00FA;
            8'hFB: data = 16'h00FB;
            8'hFC: data = 16'h00FC;
            8'hFD: data = 16'h00FD;
            8'hFE: data = 16'h00FE;
            8'hFF: data = 16'h00FF;
            default: data = 16'h0000;
        endcase
    end
endmodule