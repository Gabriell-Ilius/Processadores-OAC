`ifndef PARAM
	`include "Parametros.v"
`endif

module Controle (
    input wire clock, reset,
    input wire [6:0] Opcode,
    
    // --- LISTA DE SAÍDA COMPLETA ---
    output reg IouD,
    output reg [1:0] OrigAULA,
    output reg [1:0] OrigBULA,
    output reg [1:0] ALUOp,
    output reg [1:0] Mem2Reg,
    output reg OrigPC,
    output reg LeMem,
    output reg EscreveMem,
    output reg EscreveIR,
    output reg EscrevePC,
    output reg EscrevePCCond,
    output reg EscrevePCB,
    output reg EscreveReg,
    // ---------------------------------

    // Saída de estado para depuração
    output wire [3:0] estado 
);

    // --- 2. Registrador de Estado (Lógica Sequencial) ---
    reg [3:0] estado_atual, proximo_estado; 
    
    assign estado = estado_atual; 

    always @(posedge clock or posedge reset) begin
        if (reset)
            estado_atual <= S0;
        else
            estado_atual <= proximo_estado;
    end

    // --- 3. Lógica de Próximo Estado (Lógica Combinacional - As "Setas") ---
    always @(*) begin
        case (estado_atual)
            S0: proximo_estado = S1;
            S1: proximo_estado = S2;
            S2: // Despacho 1 (baseado no Opcode)
                case (Opcode)
                    OPC_LOAD:  proximo_estado = S3;
                    OPC_STORE: proximo_estado = S3;
                    OPC_OPIMM: proximo_estado = S3;
                    OPC_RTYPE: proximo_estado = S7;
                    OPC_BRANCH:proximo_estado = S8;
                    OPC_JAL:   proximo_estado = S10;
                    OPC_LUI:   proximo_estado = S11;
                    OPC_JALR:  proximo_estado = S12;
                    default:   proximo_estado = S0; // Segurança
                endcase
            S3: // Despacho 2 (baseado no Opcode)
                case (Opcode)
                    OPC_LOAD:  proximo_estado = S4;
                    OPC_STORE: proximo_estado = S6;
                    OPC_OPIMM: proximo_estado = S9;
                    default:   proximo_estado = S0; // Segurança
                endcase
            S4:  proximo_estado = S5;
            S5:  proximo_estado = S14;
            S6:  proximo_estado = S13;
            S7:  proximo_estado = S9;
            S8:  proximo_estado = S0;
            S9:  proximo_estado = S0;
            S10: proximo_estado = S0;
            S11: proximo_estado = S9;
            S12: proximo_estado = S0;
            S13: proximo_estado = S0;
            S14: proximo_estado = S0;
            default: proximo_estado = S0;
        endcase
    end

    // --- 4. Lógica de Saída (Lógica Combinacional - As "Bolhas") ---
    always @(*) begin
        // Valores padrão (inativos) para todos os sinais
        IouD          = 1'b0;
        LeMem         = 1'b0;
        EscreveMem    = 1'b0;
        EscreveIR     = 1'b0;
        OrigAULA      = 2'b00;
        OrigBULA      = 2'b00;
        ALUOp         = 2'b00;
        Mem2Reg       = 2'b00;
        OrigPC        = 1'b0;
        EscrevePC     = 1'b0;
        EscrevePCCond = 1'b0;
        EscrevePCB    = 1'b0;
        EscreveReg    = 1'b0;

        // Ativa os sinais específicos para cada estado
        case (estado_atual)
            S0: begin // Busca - Ciclo 1
                IouD = 1'b0;
                LeMem = 1'b1;
            end
            S1: begin // Busca - Ciclo 2 (Otimizado)
                EscreveIR = 1'b1;
                OrigAULA = 2'b10; // PC
                OrigBULA = 2'b01; // 4
                ALUOp = 2'b00;    // add
                OrigPC = 1'b0;
                EscrevePC = 1'b1;
                EscrevePCB = 1'b1;
            end
            S2: begin // Decodificação / Despacho 1
                OrigAULA = 2'b00; // PCBack
                OrigBULA = 2'b10; // Imediato
                ALUOp = 2'b00;    // add
            end
            S3: begin // Cálculo de Endereço (lw/sw/addi)
                OrigAULA = 2'b01; // A
                OrigBULA = 2'b10; // Imediato
                ALUOp = 2'b00;    // add
            end
            S4: begin // Leitura Memória - Ciclo 1 (lw)
                IouD = 1'b1;
                LeMem = 1'b1;
            end
            S5: begin // Leitura Memória - Ciclo 2 (lw)
                // Espera (MDR é escrito na borda de clock)
            end
            S6: begin // Escrita Memória - Ciclo 1 (sw)
                IouD = 1'b1;
                EscreveMem = 1'b1;
            end
            S7: begin // Execução (Tipo-R)
                OrigAULA = 2'b01; // A
                OrigBULA = 2'b00; // B
                ALUOp = 2'b10;    // Funct
            end
            S8: begin // Desvio (beq)
                OrigAULA = 2'b01; // A
                OrigBULA = 2'b00; // B
                ALUOp = 2'b01;    // sub
                OrigPC = 1'b1;
                EscrevePCCond = 1'b1;
            end
            S9: begin // Escrita Registrador (ULA -> Reg)
                EscreveReg = 1'b1;
                Mem2Reg = 2'b00;
            end
            S10: begin // Salto (jal)
                OrigPC = 1'b1;
                EscrevePC = 1'b1;
                EscreveReg = 1'b1;
                Mem2Reg = 2'b01; // PC
            end
            S11: begin // Execução (lui)
                OrigAULA = 2'b00; // Don't care
                OrigBULA = 2'b10; // Imediato
                ALUOp = 2'b11;    // OPLUI
            end
            S12: begin // Salto e Link Reg (jalr)
                OrigAULA = 2'b01; // A
                OrigBULA = 2'b10; // Imediato
                ALUOp = 2'b00;    // add
                OrigPC = 1'b1;
                EscrevePC = 1'b1;
                EscreveReg = 1'b1;
                Mem2Reg = 2'b01; // PC
            end
            S13: begin // Escrita Memória - Ciclo 2 (sw)
                // Espera
            end
            S14: begin // Escrita Registrador (Mem -> Reg)
                EscreveReg = 1'b1;
                Mem2Reg = 2'b10;
            end
        endcase
    end

endmodule