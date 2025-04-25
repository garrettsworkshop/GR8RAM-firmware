module BusInterface(
	/* Clock signal inputs */
	input CLK,
	input PHI0,
	/* Apple II reset input */
	input nRES,
	/* Card select signal inputs */
	input nDEVSEL,
	input nIOSEL,
	input nIOSTRB,
	/* Buffered address, write enable inputs */
	input [10:0] BA,
	input nWE,
	/* Data bus mux inputs */
	input [7:0] RDD,
	input [23:0] Addr,
	/* Buffered data bus output and BD buffer control */
	inout [7:0] BD,
	output nDoutOE,
	output nDinOE,
	/* Write data output to slinky registers and RAM controller */
	output reg [7:0] WRD,
	/* Bus command enable input from initialization controller */
	input BusEnable,
	/* SDRAM command outputs */
	output reg RAMRD,
	output reg RAMWR,
	output reg ROMRD,
	output reg RAMRef,
	/* Register command outputs */
	output reg BankWR,
	output reg AddrInc,
	output reg AddrHWR,
	output reg AddrMWR,
	output reg AddrLWR,
	output reg RegReset);

	/* PHI0 synchronization */
	reg [4:0] PHI0r;
	always @(posedge CLK) PHI0r[4:0] <= {PHI0r[3:0], PHI0};
	wire PHI0rise = !PHI0r[2] &&  PHI0r[1];

	/* Reset synchronization */
	reg nRESr; always @(negedge PHI0) nRESr <= nRES;

	/* Bus state counter
	 * S00 - idle/bus disabled
	 * S01-0E - PHI0
	 * S10 - wait until PHI1
	 * S11-1F - PHI1 */
	reg [4:0] S = 0;
	always @(posedge CLK) begin
		if (S==5'h00 && BusEnable && PHI0rise) S <= 5'h1;
		else if (S==5'h10 && PHI0r[1]) S <= 5'h10;
		else if (S!=5'h00) S <= S+5'h1;
	end

	/* Card select signal */
	wire CardSEL = !nDEVSEL || !nIOSEL || (!nIOSTRB && IOROMEN && BA[10:0]!=11'h7FF);

	/* Select signals ready */
	wire SelReady = S==5'h07;
	wire WriteReady = S==5'h11;

	/* Register reset command generation */
	always @(posedge CLK) begin
		if (S==5'h00 && !BusEnable) RegReset <= 1;
		else if (S==5'h1F) RegReset <= !nRESr;
	end

	/* Register enable */
	reg RegEN;
	always @(posedge CLK) begin 
		if (RegReset) RegEN <= 0;
		else if (SelReady && !nIOSEL) RegEN <= 1;
	end

	/* IOSTRB ROM enable */
	reg IOROMEN;
	always @(posedge CLK) begin
		if (RegReset) IOROMEN <= 0;
		else if (SelReady && !nIOSEL && BA[10:0]==11'h7FF) IOROMEN <= 0;
		else if (SelReady && !nIOSEL) IOROMEN <= 1;
	end

	/* Write data latch */
	always @(negedge PHI0) WRD[7:0] <= BD[7:0];

	/* Register and RAM write command generation */
	reg BankWRpre;
	reg RAMWRpre;
	reg RAMCSpre;
	reg AddrHWRpre;
	reg AddrMWRpre;
	reg AddrLWRpre;
	always @(posedge CLK) begin
		if (SelReady) begin
			BankWRpre  <= !nDEVSEL && BA[3:0]==4'hF && !nWE;
			RAMCSpre   <= !nDEVSEL && BA[3:0]==4'h3;
			RAMWRpre   <= !nDEVSEL && BA[3:0]==4'h3 && !nWE;
			AddrHWRpre <= !nDEVSEL && BA[3:0]==4'h2 && !nWE;
			AddrMWRpre <= !nDEVSEL && BA[3:0]==4'h1 && !nWE;
			AddrLWRpre <= !nDEVSEL && BA[3:0]==4'h0 && !nWE;
		end else if (S==5'h00) begin
			BankWRpre <= 0;
			RAMCSpre <= 0;
			RAMWRpre <= 0;
			AddrHWRpre <= 0;
			AddrMWRpre <= 0;
			AddrLWRpre <= 0;
		end
		BankWR <=  WriteReady && BankWRpre && RegEN;
		RAMWR <=   WriteReady && RAMWRpre && RegEN;
		AddrHWR <= WriteReady && AddrHWRpre && RegEN;
		AddrMWR <= WriteReady && AddrMWRpre && RegEN;
		AddrLWR <= WriteReady && AddrLWRpre && RegEN;
	end

	/* RAM read command generation */
	always @(posedge CLK) begin
		RAMRD <= SelReady &&  !nDEVSEL && BA[3:0]==4'h3 && nWE;
		ROMRD <= SelReady && (!nIOSEL || (!nIOSTRB && IOROMEN && BA[10:0]!=11'h7FF));
	end
	
	/* Address increment command generation after RAMWR */
	always @(posedge CLK) AddrInc <= S==5'h18 && RAMCSpre;

	/* Refresh counter */
	reg [2:0] RefC;
	wire RefCTC = RefC[2:0]==3'h6;
	always @(posedge CLK) begin
		if (S==5'h1F) begin
			if (RefCTC) RefC <= 3'h0;
			else RefC <= RefC+3'h1;
		end
	end

	/* RAM refresh command generation */
	always @(posedge CLK) RAMRef <= S==5'h1B && RefCTC;
	/* Data bus output mux */
	reg [7:0] BDout;
	wire BDoutLE = CardSEL && nWE && S==5'h0F;
	always @(posedge CLK) begin
		if (BDoutLE) begin
			if (nDEVSEL) BDout[7:0] <= RDD[7:0];
			else if (RegEN) case (BA[3:0])
				4'hF: BDout[7:0] <= 8'h00;
				4'hE: BDout[7:0] <= 8'h00;
				4'hD: BDout[7:0] <= 8'h00;
				4'hC: BDout[7:0] <= 8'h00;
				4'hB: BDout[7:0] <= 8'h00;
				4'hA: BDout[7:0] <= 8'h00;
				4'h9: BDout[7:0] <= 8'h00;
				4'h8: BDout[7:0] <= 8'h00;
				4'h7: BDout[7:0] <= 8'h10; // Hex 10 (meaning firmware 1.0)
				4'h6: BDout[7:0] <= 8'h41; // ASCII "B" (meaning rev. B)
				4'h5: BDout[7:0] <= 8'h05; // Hex 05 (meaning "4205")
				4'h4: BDout[7:0] <= 8'h47; // ASCII "G" (meaning "GW")
				4'h3: BDout[7:0] <= RDD[7:0];
				4'h2: BDout[7:0] <= Addr[23:16];
				4'h1: BDout[7:0] <= Addr[15:8];
				4'h0: BDout[7:0] <= Addr[7:0];
			endcase else BDout[7:0] <= 8'h00;
		end
	end

	/* Data bus buffer OE control */
	assign nDinOE =  !(BusEnable && CardSEL && !nWE && PHI0 && PHI0r[4]);
	assign nDoutOE = !(BusEnable && CardSEL &&  nWE && PHI0 && PHI0r[4]);
	wire BDOE =       (BusEnable && CardSEL &&  nWE && PHI0r[4]);
	assign BD[7:0] = BDOE ? BDout[7:0] : 8'bZ;

endmodule