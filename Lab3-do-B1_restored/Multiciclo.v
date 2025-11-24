`ifndef PARAM
	`include "Parametros.v"
`endif

module Multiciclo (
	input  wire clockCPU,   // Clock "lento" (ClockDIV) para a MEF e Registradores
	input  wire clockMem,   // Clock "rápido" (CLOCK) para a Memória
	input  wire reset,
	output wire [31:0] PC,      // Saída do PC atual
	output wire [31:0] Instr,   // Saída da Instrução atual
	input  wire [4:0] regin,   // Entrada para registrador de depuração
	output wire [31:0] regout,  // Saída do registrador de depuração
	output wire [3:0] estado    // Saída do estado atual da MEF
);

    // --- Sinais de Controle (Saídas do Controle.v) ---
    wire w_IouD, w_LeMem, w_EscreveMem, w_EscreveIR, w_EscrevePC, w_EscrevePCCond, w_EscrevePCB, w_EscreveReg;
    wire [1:0] w_OrigAULA, w_OrigBULA, w_ALUOp, w_Mem2Reg;
    wire w_OrigPC;
    wire [3:0] w_estado_atual; // Fio para a saída de estado

    // --- Sinais do Caminho de Dados ---
    wire [4:0] w_ALUControl;
    wire [31:0] w_Imm;
    wire [31:0] w_ReadData1, w_ReadData2;
    wire [31:0] w_MemDataRead; // Saída Mux da Memória (q_ramI ou q_ramD)
    wire [31:0] w_ALUResult;
    wire w_ZeroULA;
    wire [31:0] w_ALU_A, w_ALU_B;
    wire [31:0] w_WriteDataReg; // Dado final para escrever no Banco de Reg.
    wire [31:0] w_PC_Next;        // Próximo valor do PC
    wire [9:0]  w_MemAddrBus;     // Barramento de endereço para a memória
    wire [31:0] q_ramI, q_ramD;   // Saídas brutas das duas RAMs

    // --- Registradores Internos (Estado) ---
    // (O PC é um registrador, mas é declarado como output reg para ser visível)
    reg [31:0] PC_reg;
    reg [31:0] IR;         // Registrador de Instrução
    reg [31:0] A, B;       // Registradores de operandos (saída do Banco Reg)
    reg [31:0] SaidaALU; // Registrador de saída da ULA
    reg [31:0] MDR;      // Registrador de Dado da Memória
    reg [31:0] PCBack;   // Registrador para salvar o PC (para beq/jalr)

    // --- Conexões de Saída ---
    assign PC = PC_reg;
    assign Instr = IR;
    assign estado = w_estado_atual; // Expõe o estado atual da MEF

    // --- Instanciação dos Módulos ---

    // 1. Unidade de Controle (Nossa MEF)
    Controle control_unit (
        .clock(clockCPU),
        .reset(reset),
        .Opcode(IR[6:0]), // Opcode vem do IR
        .IouD(w_IouD),
        .LeMem(w_LeMem),
        .EscreveMem(w_EscreveMem),
        .EscreveIR(w_EscreveIR),
        .OrigAULA(w_OrigAULA),
        .OrigBULA(w_OrigBULA),
        .ALUOp(w_ALUOp),
        .Mem2Reg(w_Mem2Reg),
        .OrigPC(w_OrigPC),
        .EscrevePC(w_EscrevePC),
        .EscrevePCCond(w_EscrevePCCond),
        .EscrevePCB(w_EscrevePCB),
        .EscreveReg(w_EscreveReg),
        .estado(w_estado_atual) // Saída do estado (para depuração)
    );

    // 2. Controle da ULA
    ControleULA ula_control_unit (
        .ALUOp(w_ALUOp),
        .funct7(IR[31:25]),
        .funct3(IR[14:12]),
        .ALUControl(w_ALUControl)
    );

    // 3. Banco de Registradores
    Registers reg_file_unit (
        .iCLK(clockCPU),
        .iRST(reset),
        .iRegWrite(w_EscreveReg),
        .iReadRegister1(IR[19:15]), // rs1
        .iReadRegister2(IR[24:20]), // rs2
        .iWriteRegister(IR[11:7]),  // rd
        .iWriteData(w_WriteDataReg),
        .oReadData1(w_ReadData1),
        .oReadData2(w_ReadData2),
        .iRegDispSelect(regin),     // Depuração
        .oRegDisp(regout)           // Depuração
    );

    // 4. Gerador de Imediatos
    ImmGen imm_gen_unit (
        .iInstrucao(IR),
        .oImm(w_Imm)
    );

    // 5. ULA (ALU)
    ALU alu_unit (
        .iControl(w_ALUControl),
        .iA(w_ALU_A),
        .iB(w_ALU_B),
        .oResult(w_ALUResult),
        .Zero(w_ZeroULA)
    );

    // --- Lógica de Memória (Von Neumann com 2 blocos) ---
    
    // Mux para o barramento de endereço da memória
    // (Usa PC[11:2] para 1024 palavras de 32 bits, [9:0])
    assign w_MemAddrBus = (w_IouD == 1'b0) ? PC_reg[11:2] : SaidaALU[11:2];

    ramI MemInstrucoes (
        .address(w_MemAddrBus),
        .clock(clockMem),
        .data(32'b0), // Nunca escreve na RAM de instruções
        .wren(1'b0),  // (w_EscreveMem & ~w_IouD) -> Desabilitado por segurança
        .q(q_ramI)
    );

    ramD MemDados (
        .address(w_MemAddrBus),
        .clock(clockMem),
        .data(B), // Dado a ser escrito vem do Registrador B
        .wren(w_EscreveMem & w_IouD), // Só escreve em modo "Dados"
        .q(q_ramD)
    );

    // Mux para a saída de leitura da memória
    assign w_MemDataRead = (w_IouD == 1'b0) ? q_ramI : q_ramD;

    // --- Lógica Combinacional (Muxes do Caminho de Dados) ---

    // Mux 1: Entrada A da ULA
    assign w_ALU_A = (w_OrigAULA == 2'b10) ? PC_reg : 
                     (w_OrigAULA == 2'b01) ? A : 
                     PCBack; // (default 2'b00)

    // Mux 2: Entrada B da ULA
    assign w_ALU_B = (w_OrigBULA == 2'b10) ? w_Imm : 
                     (w_OrigBULA == 2'b01) ? 32'd4 : 
                     B; // (default 2'b00)
                     
    // Mux 3: Dado para Escrita no Banco de Registradores
    assign w_WriteDataReg = (w_Mem2Reg == 2'b10) ? MDR : 
                            (w_Mem2Reg == 2'b01) ? PC_reg : 
                            SaidaALU; // (default 2'b00)

    // Mux 4: Próximo valor do PC
    assign w_PC_Next = (w_OrigPC == 1'b1) ? SaidaALU : w_ALUResult;


    // --- Lógica Sequencial (Registradores) ---

    // 1. Registrador PC
    always @(posedge clockCPU or posedge reset) begin
        if (reset)
            PC_reg <= TEXT_ADDRESS;
        else if ( (w_EscrevePC) || (w_EscrevePCCond && w_ZeroULA) )
            PC_reg <= w_PC_Next;
    end

    // 2. Registradores Internos do Caminho de Dados
    always @(posedge clockCPU or posedge reset) begin
        if (reset) begin
            IR <= 32'b0;
            A <= 32'b0;
            B <= 32'b0;
            SaidaALU <= 32'b0;
            MDR <= 32'b0;
            PCBack <= 32'b0;
        end else begin
            // A, B, e SaidaALU são carregados em todo ciclo.
            // Seus valores são estabilizados pela MEF.
            A <= w_ReadData1;
            B <= w_ReadData2;
            SaidaALU <= w_ALUResult;
            
            // Registradores com enables explícitos
            if (w_EscreveIR)
                IR <= w_MemDataRead; // (Vindo da Memória de Instruções)
                
            if (w_EscrevePCB)
                PCBack <= PC_reg;
                
            // Carrega o MDR no final do S5 (ciclo de espera da leitura lw)
            if (w_estado_atual == S5) 
                MDR <= w_MemDataRead; // (Vindo da Memória de Dados)
        end
    end

endmodule