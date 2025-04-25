`timescale 1 ns / 1 ps

module UUT(output FCK);

	reg CLK;
	always #7 CLK = !CLK;

	wire InitDone;

	wire FCKEN;
	assign FCK = FCKEN && !CLK;

	wire [2:0] IC_RAMCmd;
	wire [24:0] IC_Addr;
	wire [7:0] IC_WRD;

	wire nFCS;
	wire MOSIout;
	wire [1:0] FD;
	SPIFlash flash(
		.FCK(FCK),
		.nFCS(nFCS),
		.DI(MOSIout),
		.DO(FD));

	reg PHI0;
	always #489 PHI0 <= !PHI0;

	wire BI_RAMRD, BI_ROMRD, BI_RAMWR, BI_RAMRef;
	wire [7:0] BI_WRD;
	wire [7:0] RDD;

	reg nDEVSEL, nIOSEL, nWE;
	initial begin
		nDEVSEL = 1;
		nIOSEL = 1;
		nWE = 1;
		#537500498
		nIOSEL = 0;
		#489
		nIOSEL = 1;
		#489
		nDEVSEL = 0;
		#489
		nDEVSEL = 1;
		nWE = 0;
		#489
		nDEVSEL = 0;
		#489
		nDEVSEL = 1;
		#489
		nDEVSEL = 0;
		#489
		nDEVSEL = 1;
		nWE = 1;
		#489
		nDEVSEL = 0;
		#489
		nDEVSEL = 1;
	end

	wire AddrHWR, AddrMWR, AddrLWR, AddrInc, BankWR, RegReset;
	wire [23:0] Addr;
	wire Bank;

	wire SetRamFactorEN;
	wire [1:0] SetSize;

	/* Apple II bus interface */
	BusInterface bi(
		/* Clock signal inputs */
		.CLK(CLK),
		.PHI0(PHI0),
		/* Apple II reset input */
		.nRES (InitDone),
		/* Card select signal inputs */
		.nDEVSEL(nDEVSEL),
		.nIOSEL(nIOSEL),
		.nIOSTRB(1'b1),
		/* Buffered address, write enable inputs */
		.BA(11'h003),
		.nWE(nWE),
		/* Data bus mux inputs */
		.RDD(RDD),
		.Addr(Addr),
		/* Data bus output and BD buffer control */
		.BD(),
		.nDoutOE(),
		.nDinOE(),
		/* Write data output to slinky registers and RAM controller */
		.WRD(BI_WRD),
		/* Initialization done input from initialization controller */
		.BusEnable(InitDone),
		/* SDRAM command outputs */
		.RAMRD(BI_RAMRD),
		.ROMRD(BI_ROMRD),
		.RAMWR(BI_RAMWR),
		.RAMRef(BI_RAMRef),
		/* Register command outputs */
		.AddrHWR(AddrHWR),
		.AddrMWR(AddrMWR),
		.AddrLWR(AddrLWR),
		.AddrInc(AddrInc),
		.BankWR(BankWR),
		.RegReset(RegReset));

    /* Slinky address and ROM bank registers */
	SlinkyRegisters registers(
		/* Clock signal */
		.CLK(CLK),
		/* Slinky/RamFactor mode bit */
		.SetRamFactorEN(SetRamFactorEN),
		/* Register command inputs */
		.AddrHWR(AddrHWR),
		.AddrMWR(AddrMWR),
		.AddrLWR(AddrLWR),
		.AddrInc(AddrInc),
		.BankWR(BankWR),
		.RegReset(RegReset),
		/* Write data input */
		.WRD(BI_WRD),
		/* Slinky address register output */
		.Addr(Addr),
		/* ROM bank register output */
		.Bank(Bank));

    /* Init controller */
	InitController ic(
		/* Clock signal */
		.CLK(CLK),
		/* Settings input and outputs */
		.SW(3'b001),
		.SetSize(SetSize),
		.SetRamFactorEN(SetRamFactorEN),
		/* Initialization done and POR outputs */
		.InitDone(InitDone),
		/* SDRAM command outputs */
		.RAMCmd(IC_RAMCmd),
		.RAMAddr(IC_Addr),
		/* SDRAM write data output */
		.WRD(IC_WRD),
		/* SPI flash bus */
		.FOE(),
		.nFCSout(nFCS),
		.nFCSin(1'b1),
		.FCKEN(FCKEN),
		.MOSIOE(),
		.MOSIout(MOSIout),
		.MOSIin(FD[1]),
		.MISO(FD[0]));

    /* SDRAM controller */
	SDRAMController ram(
		/* Clock signal */
		.CLK(CLK),
		/* POR input from init controller */
		.InitDone(InitDone),
		/* Command inputs from bus interface */
		.BI_ROMRD(BI_ROMRD),
		.BI_RAMRD(BI_RAMRD),
		.BI_RAMWR(BI_RAMWR),
		.BI_RAMRef(BI_RAMRef),
		.Bank(Bank),
		.BA(12'h003),
		.Addr(Addr),
		.BD(8'h00),
		/* Command inputs from init controller */
		.IC_RAMCmd(IC_RAMCmd),
		.IC_Addr(IC_Addr),
		.IC_WRD(IC_WRD),
		/* SDRAM bus */
		.RBA(),
		.RA(),
		.nRCS(),
		.RCKE(),
		.nRAS(),
		.nCAS(),
		.nRWE(),
		.DQML(),
		.DQMH(),
		.RDOE(),
		.RDout(),
		.RDin(),
		/* SDRAM read data */
		.RDD(RDD));

	wire RCLK = !CLK;

	initial begin
		$dumpfile("test_outputs/T1.vcd");
		$dumpvars();
		#550000000
		$finish(2);
	end

endmodule
