module Tile(
	    input 	       clk,
	    input 	       rst_n,
	    
	    input 	       init_mem_en,
	    input [15:0]       init_mem_ts,   // one-hot tile select
	    input [7:0]        init_mem_addr, // address to initialize
	    input [7:0]        init_mem_dval, // value for dmem[addr]
	    input [7:0]        init_mem_ival, // value for imem[addr]

	    input [3:0]        TileID,

	    input [12:0]       indata_e,
	    input [12:0]       indata_s,
	    input [12:0]       indata_w,
	    input [12:0]       indata_n,

	    output [12:0]      outdata_e,
	    output [12:0]      outdata_s,
	    output [12:0]      outdata_w,
	    output [12:0]      outdata_n,

	    //these are internal signals, but put them on ports to
	    //make available after Tile gets flattened in synth
	    output wire [12:0] cpu2router, 
	    output wire [12:0] router2cpu
	    
	    );


      
   wire [31:0] 		  PC;
   wire [31:0] 		  Instruction;
   wire [31:0] 		  ALUResult;
   wire [31:0] 		  RegData2;
   wire [31:0] 		  MemoryData;
   wire [31:0] 		  ReadData;
   wire [31:0] 		  NoCData;
   wire 		  MemWriteCPU;
   wire 		  MemWrite;
   wire 		  MemRead;
   wire 		  NoCWrite;
   reg 			  PacketArrived;
   
   wire [12:0] 		  indata_p;  
   wire [12:0] 		  outdata_p;   
   wire [11:0] 		  router2cpu_data;
   wire [11:0] 		  cpu2router_data;
   wire 		  empty;
   wire 		  NoCDestWrite;
   wire 		  NoCBuffWrite;
   reg [31:0] 		  destination;
   
   wire 		  data_present;
   wire 		  NOCRead;
   
   reg 			  valid_data;

   wire [7:0] 		  imem_address;
   wire [7:0] 		  imem_data;

   wire [7:0] 		  dmem_address;
   wire [7:0] 		  dmem_data;

   wire 		  readEn_inst;
   wire 		  init_en;

   assign cpu2router = indata_p;
   assign router2cpu = outdata_p;

   assign imem_address = (init_mem_en) ? init_mem_addr :        PC[7:0] ;
   assign dmem_address = (init_mem_en) ? init_mem_addr : ALUResult[7:0] ;

   assign imem_data    = (init_mem_en) ? init_mem_ival : 8'b00000000 ;
   assign dmem_data    = (init_mem_en) ? init_mem_dval : RegData2[7:0] ;

   assign readEn_inst = ((init_mem_en == 1'b0) & (rst_n == 1'b1));
   assign init_en = init_mem_en & init_mem_ts[TileID];
   
   assign ALUout = ALUResult;

   
   Processor CPU(
		 .clk(clk),
		 .rst_n(rst_n),
		 .PC(PC),
		 .Instruction(Instruction),
		 .DataAddress(ALUResult),
		 .MemWriteData(RegData2),
		 .MemWriteEn(MemWriteCPU),
		 .MemReadEn(MemRead),
		 .NoCWrite(NoCWrite),
		 .MemReadData(ReadData) 
		 );

   //instruction memory
   Memory InstructionMemory(
			    .clk(clk),
			    .in_Address(imem_address),
			    .in_Data(imem_data),
			    .in_WriteEn(init_en),
			    .in_ReadEn(readEn_inst),
			    .out_Data(Instruction)
			    );

   //data memory
   Memory DataMemory(
		     .clk(clk),
		     .in_Address(dmem_address),
		     .in_Data(dmem_data),
		     .in_WriteEn(MemWrite),
		     .in_ReadEn(MemRead),
		     .out_Data(MemoryData)
		     );

   assign MemWrite = ((MemWriteCPU & ~ALUResult[31]) | init_en );
   assign ReadData = ALUResult[31] ? NoCData : MemoryData;
   
   assign NoCData = ALUResult[4] ? {24'b0, router2cpu_data[7:0]}: {31'b0, PacketArrived};
   assign NOCRead = MemRead & ALUResult[4];

   
   always @(posedge clk)
     begin
	if(!rst_n) begin
	   PacketArrived  <= 1'b0;
	   valid_data     <= 1'b0;
	   destination    <= 32'hBAD0BAD0;
	end	
	else begin
	   PacketArrived  <= data_present;
	   valid_data     <= ~empty;
	   if (NoCDestWrite)
	     destination  <= RegData2;
	end
	
     end

   assign indata_p[12] = valid_data; 
   
   
   syn_fifo CPU2Router ( 
			 .clk(clk), 
			 .rst(rst_n),
			 .wr_cs(1'b1),
			 .rd_cs(1'b1), 
			 .data_in(RegData2[11:0]), 
			 .rd_en(~empty), 
			 .wr_en(NoCWrite), 
			 .data_out(indata_p[11:0]), 
			 .empty(empty), 
			 .full()
			 );

   syn_fifo Router2CPU ( 
			 .clk(clk), 
			 .rst(rst_n),
			 .wr_cs(1'b1), 
			 .rd_cs(1'b1), 
			 .data_in(outdata_p[11:0]), 
			 .rd_en(NOCRead), 
			 .wr_en(outdata_p[12]), 
			 .data_out(router2cpu_data), 
			 .empty(), 
			 .full(data_present)
			 );   
   
   router router_inst (
		       .clk(clk), 
		       .rst_n(rst_n), 		       
		       .ID(TileID), 
		       .indata_p(indata_p), 
		       .indata_e(indata_e), 
		       .indata_s(indata_s), 
		       .indata_w(indata_w), 
		       .indata_n(indata_n), 
		       .outdata_p(outdata_p), 
		       .outdata_e(outdata_e), 
		       .outdata_s(outdata_s), 
		       .outdata_w(outdata_w), 
		       .outdata_n(outdata_n)
		       );
   
   
   
   
endmodule
