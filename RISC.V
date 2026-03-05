`timescale 1ns / 1ps
module Program_Counter(input clk, reset,
                       input [31:0] PC_in,
                       output reg [31:0] PC_out);
always @(posedge clk or posedge reset) begin
    if (reset)
        PC_out <= 32'b0;
    else
        PC_out <= PC_in;
end
endmodule

module PCplus4(input [31:0] fromPC,
               output [31:0] NextoPC);
assign NextoPC = fromPC + 32'd4;
endmodule

module Instruction_Memory(
    input [31:0] read_address,
    output [31:0] instruction_out
);

reg [31:0] IMemory [0:63];
integer k;

assign instruction_out = IMemory[read_address >> 2];

initial begin
    for (k = 0; k < 64; k = k + 1)
        IMemory[k] = 32'b0;

        IMemory[0]  = 32'b0000000_00011_00010_000_00001_0110011; // add x1,x2,x3
        IMemory[1]  = 32'b0100000_00101_00100_000_00110_0110011; // sub x6,x4,x5
        IMemory[2]  = 32'b0000000_00101_00100_111_00111_0110011; // and x7,x4,x5
        IMemory[3]  = 32'b0000000_00101_00100_110_01000_0110011; // or  x8,x4,x5
        IMemory[4]  = 32'b0000000_00101_00100_010_01001_0110011; // slt x9,x4,x5
        IMemory[5]  = 32'b000000000101_00100_000_01010_0010011; // addi x10,x4,5
        IMemory[6]  = 32'b000000000001_00100_110_01011_0010011; // ori  x11,x4,1
        IMemory[7]  = 32'b000000001000_00100_010_01100_0000011; // lw   x12,8(x4)
        IMemory[8]  = 32'b0000000_01100_00100_010_01000_0100011; // sw   x12,8(x4)
        IMemory[9]  = 32'h00948663;                              // beq  x9,x9,12

end
endmodule

module Reg_File(input clk, reset, RegWrite,
                input [4:0] Rs1, Rs2, Rd,
                input [31:0] Write_data,
                output [31:0] read_data1, read_data2);

reg [31:0] Registers [0:31];
integer k;

initial begin
    for (k = 0; k < 32; k = k + 1)
        Registers[k] = k;
end

always @(posedge clk or posedge reset) begin
    if (reset)
        for (k = 0; k < 32; k = k + 1)
            Registers[k] <= 32'b0;
    else if (RegWrite && Rd != 0)
        Registers[Rd] <= Write_data;

    Registers[0] <= 32'b0;
end

assign read_data1 = Registers[Rs1];
assign read_data2 = Registers[Rs2];

endmodule

module ImmGen(input [6:0] Opcode,
              input [31:0] instruction,
              output reg [31:0] ImmExt);

always @(*) begin
    case (Opcode)
        7'b0010011, 7'b0000011:
            ImmExt = {{20{instruction[31]}}, instruction[31:20]};
        7'b0100011:
            ImmExt = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
        7'b1100011:
            ImmExt = {{19{instruction[31]}}, instruction[31],
                       instruction[30:25], instruction[11:8], 1'b0};
        default: ImmExt = 32'b0;
    endcase
end
endmodule

module Control_Unit(input [6:0] opcode,
                    output reg Branch, MemRead, MemtoReg,
                    output reg MemWrite, ALUSrc, RegWrite,
                    output reg [1:0] ALUOp);

always @(*) begin
    {Branch,MemRead,MemtoReg,MemWrite,ALUSrc,RegWrite,ALUOp} = 8'b0;
    case (opcode)
        7'b0110011: begin RegWrite=1; ALUOp=2'b10; end
        7'b0010011: begin RegWrite=1; ALUSrc=1; ALUOp=2'b00; end
        7'b0000011: begin RegWrite=1; MemRead=1; MemtoReg=1; ALUSrc=1; ALUOp=2'b00; end
        7'b0100011: begin MemWrite=1; ALUSrc=1; ALUOp=2'b00; end
        7'b1100011: begin Branch=1; ALUOp=2'b01; end
    endcase
end
endmodule

module ALU_Control(input [1:0] ALUOp,
                   input fun7,
                   input [2:0] fun3,
                   output reg [3:0] Control_out);

always @(*) begin
    case ({ALUOp, fun7, fun3})
        6'b00_0_000: Control_out = 4'b0010;
        6'b01_0_000: Control_out = 4'b0110;
        6'b10_0_000: Control_out = 4'b0010;
        6'b10_1_000: Control_out = 4'b0110;
        6'b10_0_111: Control_out = 4'b0000;
        6'b10_0_110: Control_out = 4'b0001;
        6'b10_0_010: Control_out = 4'b0111;
        default:     Control_out = 4'b0000;
    endcase
end
endmodule

module ALU_unit(input [31:0] A, B,
                input [3:0] Control_in,
                output reg [31:0] ALU_Result,
                output reg zero);

always @(*) begin
    case (Control_in)
        4'b0000: ALU_Result = A & B;
        4'b0001: ALU_Result = A | B;
        4'b0010: ALU_Result = A + B;
        4'b0110: ALU_Result = A - B;
        4'b0111: ALU_Result = (A < B) ? 1 : 0;
        default: ALU_Result = 0;
    endcase
    zero = (ALU_Result == 0);
end
endmodule

module Data_Memory(input clk, reset, MemWrite, MemRead,
                   input [31:0] address, Writedata,
                   output [31:0] MemData_out);

reg [31:0] D_Memory [0:63];
integer k;

assign MemData_out = MemRead ? D_Memory[address >> 2] : 32'b0;

always @(posedge clk or posedge reset) begin
    if (reset)
        for (k=0; k<64; k=k+1)
            D_Memory[k] <= 32'b0;
    else if (MemWrite)
        D_Memory[address >> 2] <= Writedata;
end
endmodule

module Mux2(input sel, input [31:0] A, B, output [31:0] Y);
assign Y = sel ? B : A;
endmodule

module AND_logic(input branch, zero, output and_out);
assign and_out = branch & zero;
endmodule

module top (
    input clk,
    input reset
);


wire [31:0] PC, PC4, PC_branch, PC_next;
wire [31:0] instruction;
wire [31:0] Rd1, Rd2;
wire [31:0] ImmExt;
wire [31:0] ALU_in2, ALU_out;
wire [31:0] MemData, WriteBack;

wire Branch, MemRead, MemWrite, ALUSrc, RegWrite, MemtoReg, zero;
wire [1:0] ALUOp;
wire [3:0] ALUctrl;
wire PCsrc;


assign PC_next = (PCsrc === 1'b1) ? PC_branch : PC4;

Program_Counter PCU (
    .clk(clk),
    .reset(reset),
    .PC_in(PC_next),
    .PC_out(PC)
);

PCplus4 PCADD (.fromPC(PC), .NextoPC(PC4));


Instruction_Memory IM (
    .read_address(PC),
    .instruction_out(instruction)
);


Reg_File RF (
    .clk(clk),
    .reset(reset),
    .RegWrite(RegWrite),
    .Rs1(instruction[19:15]),
    .Rs2(instruction[24:20]),
    .Rd(instruction[11:7]),
    .Write_data(WriteBack),
    .read_data1(Rd1),
    .read_data2(Rd2)
);

ImmGen IG (
    .Opcode(instruction[6:0]),
    .instruction(instruction),
    .ImmExt(ImmExt)
);


Control_Unit CU (
    .opcode(instruction[6:0]),
    .Branch(Branch),
    .MemRead(MemRead),
    .MemtoReg(MemtoReg),
    .MemWrite(MemWrite),
    .ALUSrc(ALUSrc),
    .RegWrite(RegWrite),
    .ALUOp(ALUOp)
);

ALU_Control AC (
    .ALUOp(ALUOp),
    .fun7(instruction[30]),
    .fun3(instruction[14:12]),
    .Control_out(ALUctrl)
);

Mux2 ALUMUX (.sel(ALUSrc), .A(Rd2), .B(ImmExt), .Y(ALU_in2));

ALU_unit ALU (
    .A(Rd1),
    .B(ALU_in2),
    .Control_in(ALUctrl),
    .ALU_Result(ALU_out),
    .zero(zero)
);

AND_logic ANDG (.branch(Branch), .zero(zero), .and_out(PCsrc));
assign PC_branch = PC + ImmExt;

Data_Memory DM (
    .clk(clk),
    .reset(reset),
    .MemWrite(MemWrite),
    .MemRead(MemRead),
    .address(ALU_out),
    .Writedata(Rd2),
    .MemData_out(MemData)
);


Mux2 WBMUX (.sel(MemtoReg), .A(ALU_out), .B(MemData), .Y(WriteBack));

endmodule


