module sequencer (
    input clk,
    input start,
    input reset,
    input continue,
    output ready,
    output [4:0] ctl_a,
    output [4:0] ctl_b,
    output [1:0] ctl_c,
    output [1:0] ctl_d,
    output ctl_e,
    output ctl_f
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

    assign pc_in = (continue|seq_reg_q) ? pc_set : pc_inc;

    assign pc_inc = pc_out + 8'b1;

    assign pc_set = (seq_reg_set) ? 8'b0 : pc_out;

    seq_reg r0 (.clk(clk), .set(seq_reg_set), .clear(start), .q(seq_reg_q));
    pc_reg r_pc (.clk(clk), .w(continue), .din(pc_in), .q(pc_out));

    ROM ctl_words (.dir(pc_out), .dout({ctl_a, ctl_b, ctl_c, ctl_d, ctl_e, ctl_f}));

endmodule

module ROM (
    input [7:0] dir,
    output [15:0] dout
);
    reg [15:0] rom [0:255];
    reg [15:0] reg_dout;

    initial begin
        $readmemh("rom_data.hex", rom);
    end

    always @(*) begin
        reg_dout = rom[dir];
    end
    assign dout = reg_dout;
endmodule

module pc_reg (
    input clk,
    input w,
    input [7:0] din,
    output [7:0] q
);
    reg reg_q;
    always @(posedge clk) begin
        if (w)
            reg_q <= w;
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