`ifndef PARAM
	// `include "Parametros.v" // Removido para evitar re-declaração
`endif

module TopDE (
	// Entradas
	input wire CLOCK, Reset,
	input wire [4:0] Regin,
	
	// Saídas
	output wire ClockDIV,
	output wire [31:0] PC,
	output wire [31:0] Instr,
	output wire [31:0] Regout,
	output wire [3:0] Estado // Corrigido para "Estado" (maiúsculo)
);
	
	// --- DIVISOR DE CLOCK (divide por 2) ---
	// Gera um pulso (ClockDIV) para a CPU a cada 2 ciclos do CLOCK da memória.
	
	reg clock_counter; // Alterado para 1 bit (era [1:0])
	
	always @(posedge CLOCK or posedge Reset)
	begin
		if (Reset)
			clock_counter <= 1'b0;
		else
			clock_counter <= clock_counter + 1; // Lógica de 1 bit: 0->1, 1->0
	end
	
	// Gera um pulso no segundo ciclo (quando o contador for 1)
	assign ClockDIV = (clock_counter == 1'b1); 
	// --- FIM DO DIVISOR ---


	// --- Laboratório 3: Instancia o Processador Multiciclo ---
	Multiciclo MULTI1 (
		.clockCPU(ClockDIV), // Clock "lento" (agora dividido por 2)
		.clockMem(CLOCK),    // Clock "rápido" para a Memória
		.reset(Reset), 
		.PC(PC), 
		.Instr(Instr), 
		.regin(Regin), 
		.regout(Regout),
		.estado(Estado)      // Conecta a saída da MEF à porta de saída do TopDE
	);
		
endmodule