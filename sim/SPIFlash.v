module SPIFlash(
		input FCK,
		input nFCS,
		input DI,
		output [1:0] DO);

	reg nStart = 0;
	always @(posedge FCK, posedge nFCS) begin
		if (nFCS) nStart <= 0;
		else if (!nFCS) nStart <= 1;
	end

	reg [7:0] ROM[0:255];
	initial $readmemh("sim/rom.hex", ROM);

	reg [37:0] DIr;
	always @(posedge FCK) DIr[37:0] <= {DIr[36:0], DI};
	reg [37:0] nStartr;
	always @(posedge FCK) nStartr[37:0] <= {nStartr[36:0], nStart};

	reg Read;
	reg [23:0] ReadPtrW;
	reg [1:0] ReadPtrB;

	always @(posedge FCK, posedge nFCS) begin
		if (nFCS) Read <= 0;
		else if (DIr[37:30]==8'h3B && !nStartr[37]) Read <= 1;
	end

	always @(posedge FCK, posedge nFCS) begin
		if (nFCS) begin
			DO[1:0] <= 2'b00;
			ReadPtrW <= 0;
			ReadPtrB <= 0;
		end else if (Read) begin
			case (ReadPtrB[1:0])
				0: DO[1:0] <= ROM[ReadPtrW[7:0]][1:0];
				1: DO[1:0] <= ROM[ReadPtrW[7:0]][3:2];
				2: DO[1:0] <= ROM[ReadPtrW[7:0]][5:4];
				3: DO[1:0] <= ROM[ReadPtrW[7:0]][7:6];
			endcase
			if (ReadPtrB[1:0]==3) ReadPtrW <= ReadPtrW+24'h1;
			ReadPtrB <= ReadPtrB+2'h1;
		end
	end

endmodule
