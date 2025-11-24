`ifndef PARAM
	`include "Parametros.v" 
`endif

module Uniciclo (
	input wire clockCPU, clockMem,
	input wire reset,
	output reg [31:0] PC,
	output wire [31:0] Instr,
	input  wire [4:0] regin,
	output wire [31:0] regout
);

    wire [31:0] PCNext, PCPlus4, PCTargetBranch, PCTargetJump;
    wire [31:0] Imm;
    wire [31:0] ReadData1, ReadData2;
    wire [31:0] ALUResult, ALUB_Input;
    wire [31:0] MemDataRead;
    wire [31:0] WriteDataReg;
    wire ZeroULA;
    wire Mem2Reg, LeMem, Branch, EscreveMem, OrigULA, EscreveReg, Jump;
    wire [1:0] ALUOp;
    wire [4:0] ALUControl;
    wire PCSrc;

    initial begin
        PC <= TEXT_ADDRESS;
        Instr  <= 32'b0;
        regout <= 32'b0;
    end

    assign PCPlus4 = PC + 32'd4;
    assign PCTargetBranch = PC + Imm;
    assign PCTargetJump = ALUResult;

    assign PCSrc = (Branch & ZeroULA) | Jump;
    assign PCNext = PCSrc ? (Jump & (Instr[6:0] == OPC_JALR) ? PCTargetJump : PCTargetBranch) 
                           : PCPlus4;

    always @(posedge clockCPU or posedge reset) begin
        if (reset)
            PC <= TEXT_ADDRESS;
        else
            PC <= PCNext;
    end

    ramI MemInstrucoes (
        .address(PC[11:2]),
        .clock(clockMem),
        .data(),
        .wren(1'b0),
        .q(Instr)
    );

    Registers BancoRegs (
        .iCLK(clockCPU), .iRST(reset), .iRegWrite(EscreveReg),
        .iReadRegister1(Instr[19:15]), .iReadRegister2(Instr[24:20]), .iWriteRegister(Instr[11:7]),
        .iWriteData(WriteDataReg), .oReadData1(ReadData1), .oReadData2(ReadData2),
        .iRegDispSelect(regin), .oRegDisp(regout)
    );

    ImmGen GeradorImm (.iInstrucao(Instr), .oImm(Imm));

    Controle UnidadeControle (
        .opcode(Instr[6:0]), .Mem2Reg(Mem2Reg), .LeMem(LeMem), .Branch(Branch),
        .ALUOp(ALUOp), .EscreveMem(EscreveMem), .OrigULA(OrigULA),
        .EscreveReg(EscreveReg), .Jump(Jump)
    );

    ControleULA ULAControle (
        .ALUOp(ALUOp), .funct7(Instr[31:25]), .funct3(Instr[14:12]), .ALUControl(ALUControl)
    );

    assign ALUB_Input = OrigULA ? Imm : ReadData2;

    ALU UnidadeLogicaAritmetica (
        .iControl(ALUControl), .iA(ReadData1), .iB(ALUB_Input),
        .oResult(ALUResult), .Zero(ZeroULA)
    );

    ramD MemDados (
        .address(ALUResult[11:2]), .clock(clockMem), .data(ReadData2),
        .wren(EscreveMem), .q(MemDataRead)
    );

    assign WriteDataReg = Jump ? PCPlus4 :
                         (Mem2Reg ? MemDataRead :
                          ALUResult);
endmodule