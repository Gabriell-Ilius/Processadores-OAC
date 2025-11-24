`ifndef PARAM
	`include "Parametros.v"
`endif

module ALU (
	input 		 [4:0]  iControl,
	input signed [31:0] iA,
	input signed [31:0] iB,
	output reg [31:0] oResult,
	output wire Zero
	);

assign Zero = (oResult==32'b0);

always @(*)
begin
    case (iControl)
		OPAND: oResult  = iA & iB;
		OPOR:  oResult  = iA | iB;
		OPADD: oResult  = iA + iB;
		OPSUB: oResult  = iA - iB;
		OPSLT: oResult  = (iA < iB) ? 32'd1 : 32'd0;
		OPLUI: oResult  = iB;
		default: oResult = ZERO;
    endcase
end

endmodule