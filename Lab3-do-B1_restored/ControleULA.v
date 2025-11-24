`ifndef PARAM
	`include "Parametros.v"
`endif

module ControleULA (
    input wire [1:0] ALUOp,
    input wire [6:0] funct7,
    input wire [2:0] funct3,
    output reg [4:0] ALUControl
);

    always @(*) begin
        case (ALUOp)
            2'b00:
                ALUControl = OPADD;
            2'b01:
                ALUControl = OPSUB;
            2'b10:
                case (funct3)
                    FUNCT3_ADD:
                        if (funct7 == FUNCT7_ADD)
                            ALUControl = OPADD;
                        else // FUNCT7_SUB
                            ALUControl = OPSUB;
                    FUNCT3_SLT:
                        ALUControl = OPSLT;
                    FUNCT3_OR:
                        ALUControl = OPOR;
                    FUNCT3_AND:
                        ALUControl = OPAND;
                    default: ALUControl = OPNULL;
                endcase
            2'b11:
                ALUControl = OPLUI;
            default: ALUControl = OPNULL;
        endcase
    end
endmodule