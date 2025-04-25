module SDRAMController(
	/* Clock signal */
	input CLK,
	/* POR input from init controller */
	input InitDone,
	/* Command inputs from bus interface */
	input BI_ROMRD,
	input BI_RAMRD,
	input BI_RAMWR,
	input BI_RAMRef,
	input Bank,
	input [11:0] BA,
	input [23:0] Addr,
	input [7:0] BD,
	/* Command inputs from init controller */
	input [2:0] IC_RAMCmd,
	input [24:0] IC_Addr,
	input [7:0] IC_WRD,
	/* SDRAM bus */
	output reg [1:0] RBA,
	output reg [12:0] RA,
	output reg RCKE,
	output nRCS,
	output reg nRAS,
	output reg nCAS,
	output reg nRWE,
	output reg DQML,
	output reg DQMH,
	output reg RDOE = 0,
	output reg [7:0] RDout,
	inout [7:0] RDin,
	/* SDRAM read data */
	output reg [7:0] RDD);

	`define RC_NOP (3'h0)
	`define RC_LDM (3'h1)
	`define RC_ACT (3'h2)
	`define RC_WR  (3'h3)
	`define RC_PC  (3'h4)
	`define RC_Ref (3'h5)

	reg [2:0] RS = 0;
	reg [2:0] CS = 0;

	always @(posedge CLK) begin
		case (RS)
			0: begin // Power-on reset & initialization
				if (InitDone) RS <= 1;
				CS <= 0;
			end 1: begin // Idle
				if (BI_ROMRD) RS <= 2;
				else if (BI_RAMRD) RS <= 3;
				else if (BI_RAMWR) RS <= 4;
				else if (BI_RAMRef) RS <= 5;
				CS <= 0;
			end 2, 3, 4: begin // ROM read, RAM read, RAM write
				if (CS==5) begin
					RS <= 1;
					CS <= 0;
				end else CS <= CS+3'h1;
			end 5: begin // Refresh
				if (CS==3) begin
					RS <= 1;
					CS <= 0;
				end else CS <= CS+3'h1;
			end default: begin
				RS <= 1;
				CS <= 0;
			end
		endcase
	end

	always @(posedge CLK) begin
		case (RS)
			0: begin
				case (IC_RAMCmd) // Power-on reset and initialization
					`RC_LDM: begin
						RCKE <= 1;
						nRAS <= 0;
						nCAS <= 0;
						nRWE <= 0;
						RBA[1:0] <= 2'b00;
						RA[12:0] <= 13'b0001000100000;
					end `RC_ACT: begin
						RCKE <= 1;
						nRAS <= 0;
						nCAS <= 1;
						nRWE <= 1;
						RBA[1:0] <= IC_Addr[11:10];
						RA[12:0] <= IC_Addr[24:12];
					end `RC_WR: begin
						RCKE <= 1;
						nRAS <= 1;
						nCAS <= 0;
						nRWE <= 0;
						RBA[1:0] <= IC_Addr[11:10];
						RA[12:11] <= 2'b00;
						RA[10] <= 1'b0; // no auto-precharge
						RA[9] <= 1'b0;
						RA[8:0] <= IC_Addr[9:1];
					end `RC_PC: begin
						RCKE <= 1;
						nRAS <= 0;
						nCAS <= 1;
						nRWE <= 0;
						RA[10] <= 1'b1; // precharge all
					end `RC_Ref: begin
						RCKE <= 1;
						nRAS <= 0;
						nCAS <= 0;
						nRWE <= 1;
					end `RC_NOP: begin
						RCKE <= 1;
						nRAS <= 1;
						nCAS <= 1;
						nRWE <= 1;
					end default: begin
						RCKE <= 1;
						nRAS <= 1;
						nCAS <= 1;
						nRWE <= 1;
					end
				endcase
				if (IC_RAMCmd==`RC_WR) begin
					DQML <=  IC_Addr[0];
					DQMH <= !IC_Addr[0];
				end else begin
					DQML <= 1;
					DQMH <= 1;
				end
			end 1: begin // Idle
				RCKE <= BI_ROMRD || BI_RAMRD || BI_RAMWR || BI_RAMRef;
				nRAS <= 1;
				nCAS <= 1;
				nRWE <= 1;
				DQML <= 1;
				DQMH <= 1;
			end 2, 3, 4: case (CS) // Read ROM/RAM
				0: begin
					// ACT CKD
					RCKE <= 0;
					nRAS <= 0;
					nCAS <= 1;
					nRWE <= 1;
					if (RS==2) begin
						RBA[1:0] <= BA[11:10];
						RA[12] <= 1;
						RA[11:1] <= 11'h000;
						RA[0] <= Bank;
					end else begin
						RBA[1:0] <= Addr[11:10];
						RA[12] <= 1'b0;
						RA[11:0] <= Addr[23:12];
					end
					DQML <= 1;
					DQMH <= 1;
				end 1: begin
					// NOP CKE
					RCKE <= 1;
					nRAS <= 1;
					nCAS <= 1;
					nRWE <= 1;
					DQML <= 1;
					DQMH <= 1;
				end 2: begin
					// RD CKE
					RCKE <= 1;
					nRAS <= 1;
					nCAS <= 0;
					nRWE <= !RS[2];
					RA[12:11] <= 2'b00;
					RA[10] <= 1'b0; // no auto-precharge
					RA[9] <= 1'b0;
					if (RS==2) begin
						DQML <=  BA[0];
						DQMH <= !BA[0];
						RBA[1:0] <= BA[11:10];
						RA[8:0] <= BA[9:1];
					end else begin
						DQML <=  Addr[0];
						DQMH <= !Addr[0];
						RBA[1:0] <= Addr[11:10];
						RA[8:0] <= Addr[9:1];
					end
				end 3: begin
					// NOP CKD
					RCKE <= 0;
					nRAS <= 1;
					nCAS <= 1;
					nRWE <= 1;
					DQML <= 1;
					DQMH <= 1;
				end 4: begin
					// NOP CKE
					RCKE <= 1;
					nRAS <= 1;
					nCAS <= 1;
					nRWE <= 1;
					DQML <= 1;
					DQMH <= 1;
				end 5: begin
					// PC all CKD
					RCKE <= 0;
					nRAS <= 0;
					nCAS <= 1;
					nRWE <= 0;
					RA[10] <= 1'b1; // precharge all
					DQML <= 1;
					DQMH <= 1;
				end default: begin
					// NOP CKD
					RCKE <= 0;
					nRAS <= 1;
					nCAS <= 1;
					nRWE <= 1;
					DQML <= 1;
					DQMH <= 1;
				end
			endcase 5: case (CS) // Refresh
				0: begin
					// AREF CKE
					RCKE <= 1;
					nRAS <= 0;
					nCAS <= 0;
					nRWE <= 1;
					DQML <= 1;
					DQMH <= 1;
				end 1, 2, 3: begin
					// NOP CKD
					RCKE <= 0;
					nRAS <= 1;
					nCAS <= 1;
					nRWE <= 1;
					DQML <= 1;
					DQMH <= 1;
				end default: begin
					// NOP CKD
					RCKE <= 0;
					nRAS <= 1;
					nCAS <= 1;
					nRWE <= 1;
					DQML <= 1;
					DQMH <= 1;
				end
			endcase default: begin // Invalid state
				// NOP CKE
				RCKE <= 1;
				nRAS <= 1;
				nCAS <= 1;
				nRWE <= 1;
				DQML <= 1;
				DQMH <= 1;
			end
		endcase
	end
	
	/* Write data OE control */
	always @(posedge CLK) begin
		if (!InitDone && IC_RAMCmd[1]) RDOE <= 1; 
		else if (InitDone) RDOE <= RS==4 && (CS==1 || CS==2);
	end

	/* Write data latch */
	wire WRDLE = IC_RAMCmd==`RC_WR || (RS==4 && CS==2);
	always @(posedge CLK) begin
		if (WRDLE) RDout[7:0] <= !InitDone ? IC_WRD[7:0] : BD[7:0];
	end
	
	/* Read data latch control */
	wire RDDLE = (RS==3'h2 || RS==3'h3) && CS==3'h5;
	always @(posedge CLK) if (RDDLE) RDD[7:0] <= RDin[7:0];
		
	assign nRCS = 0;
endmodule