`timescale 10 ns / 1 ns

module mycpu_top(
	input  resetn,
	input  clk,

	output  [31:0] debug_wb_pc,
	output  [ 3:0] debug_wb_rf_wen,
	output  [ 4:0] debug_wb_rf_wnum,
	output  [31:0] debug_wb_rf_wdata,
    
	output inst_sram_en,
	output [ 3:0] inst_sram_wen,
	output [31:0] inst_sram_addr,
	output [31:0] inst_sram_wdata,
	input  [31:0] inst_sram_rdata,
	
	output data_sram_en,
	output [ 3:0] data_sram_wen,
	output [31:0] data_sram_addr,
	output [31:0] data_sram_wdata,
	input  [31:0] data_sram_rdata
);

//LO HI
reg  [31:0]  LO;
reg  [31:0]  HI;
wire [31:0]  LO_true;
wire [31:0]  HI_true;

//mul
wire [66:0] mul_result;
wire [32:0] mul_a;
wire [32:0] mul_b;

//div
wire [39:0] s_axis_divisor_tdata;
wire        s_axis_divisor_tready;
reg        s_axis_divisor_tvalid;
wire [39:0] s_axis_dividend_tdata;
wire        s_axis_dividend_tready;
reg        s_axis_dividend_tvalid;
wire [79:0] m_axis_dout_tdata;
wire        m_axis_dout_tvalid;



//register
wire [31:0]  rdata1;  //register read data1
wire [31:0]  rdata2;  //register read data2
wire [31:0]  rdata1_true;
wire [31:0]  rdata2_true;
wire [31:0]  wdata;   //register write data
wire [ 4:0]  waddr;   //register write address

wire [31:0]  data1;       //alu data1
wire [31:0]  data2;       //alu data2
wire [ 3:0]  alu_control; //alu control sigal
wire [31:0]  alu_result1; //alu result: data
wire [31:0]  alu_result2; //alu result: PC	
wire         carryout;    //alu carryout
wire         overflow;    //alu overflow
wire         zero;        //alu zero

wire [31:0]  J_address;     //J: address to be jumped to in the next cycle
reg  [31:0]  PC;
wire [31:0]  PC_next;

wire [31:0]  shift_imm_left_2;  //extended immediate unsigned word shift left 2
wire [31:0]  extension_zero;    //immediate extended with sixteen 0 at the end
wire [27:0]  shift_left_2;      //instruction [25:0] shift left 2
wire [31:0]  sign_extension;    //sign-extended immediate unsigned word
wire [31:0]  zero_extension;    //zero-extended immediate unsigned word
wire         PC_write;           //PC write enable signal
wire [5:0]   op;
wire [5:0]   func;
wire [4:0]   rs;
wire [4:0]   rt;
wire [4:0]   rd;
wire [4:0]   sa;              //6-10 bits in R-type instruction 
wire         rst;             //high level effective
wire [31:0]  Instruction;     //instruction SRAM: instruction 
wire [31:0]  Address;         //data SRAM: address
wire [31:0]  Write_data;      //data SRAM: write data
wire [31:0]  Read_data;       //data SRAM: read data 
wire         Mem_en;
wire         Mem_wen;

//debug
wire [31:0] exe_pc;
wire [31:0] mem_pc;
wire [31:0] wb_pc;

//Instructions
wire ADD;
wire ADDI;
wire ADDIU;
wire ADDU;
wire AND;
wire ANDI;
wire BEQ;
wire BGEZ;
wire BGEZAL;
wire BGTZ;
wire BLEZ;
wire BLTZ;
wire BLTZAL;
wire BNE;
wire BREAK;
wire DIV;
wire DIVU;
wire ERET;
wire J;
wire JAL;
wire JALR;
wire JR;
wire LB;
wire LBU;
wire LH;
wire LHU;
wire LUI;
wire LW;
wire LWL;
wire LWR;
wire MFCO;
wire MFHI;
wire MFLO;
wire MTCO;
wire MTHI;
wire MTLO;
wire MULT;
wire MULTU;
wire NOR;
wire OR;
wire ORI;
wire SB;
wire SH;
wire SLL;
wire SLLV;
wire SLT;
wire SLTI;
wire SLTIU;
wire SLTU;
wire SRA;
wire SRAV;
wire SRL;
wire SRLV;
wire SUB;
wire SUBU;
wire SW;
wire SWL;
wire SWR;
wire SYSCALL;
wire XOR;
wire XORI;

//Control signals
wire         RegWrite;
wire         wb_RegWrite;
wire [ 2:0]  ALUSrcB;   //exe_alu
wire [ 1:0]  PCSrc;
wire [ 1:0]  RegDst;
wire [ 2:0]  MemtoReg;
wire [31:0]  offset;
wire [ 1:0]  ALUSrcA;
wire         ALUSrcB2;   //pc_alu

/*----------------------------pipe1----------------------------*/
wire        valid_in; 
reg         pipe1_valid;
reg [ 95:0] pipe1_data;
wire        pipe1_allowin;
wire        pipe1_ready_go;
wire        pipe1_to_pipe2_valid;
 
/*----------------------------pipe2----------------------------*/
reg         pipe2_valid;
reg [183:0] pipe2_data;
wire        pipe2_allowin;
wire        pipe2_ready_go;
wire        pipe2_to_pipe3_valid;

/*----------------------------pipe3----------------------------*/
reg         pipe3_valid;
reg [215:0] pipe3_data;///////////////////////////////////////// change 183 -> 215
wire        pipe3_allowin;
wire        pipe3_ready_go;
wire        pipe3_to_pipe4_valid;

/*----------------------------pipe4----------------------------*/
reg         pipe4_valid;
reg [151:0] pipe4_data;
wire        pipe4_allowin;
wire        pipe4_ready_go;

//distinguish instructions
assign op           = pipe1_data[ 31: 26];            //op
assign rs           = pipe1_data[ 25: 21];            //rs
assign rt           = pipe1_data[ 20: 16];            //rt
assign rd           = pipe1_data[ 15: 11];            //rd
assign sa           = pipe1_data[ 10:  6];            //sa
assign func         = pipe1_data[  5:  0];            //func

assign J_address        = {PC[31:28],shift_left_2};
assign shift_left_2     = {pipe1_data[25: 0],2'b00};
assign sign_extension   = {{16{pipe1_data[15]}},pipe1_data[15: 0]};
assign shift_imm_left_2 = sign_extension<<2;
assign zero_extension   = {{16{1'b0}},pipe1_data[15: 0]};
assign extension_zero   = {pipe1_data[15: 0],16'd0};
assign wb_RegWrite      = (pipe4_valid)?pipe4_data[82:82]:0;
 
assign ADD     = (op==6'b000000) & (sa==5'b00000) & (func==6'b100000);
assign ADDI    = (op==6'b001000);
assign ADDIU   = (op==6'b001001);
assign ADDU    = (op==6'b000000) & (sa==5'b00000) & (func==6'b100001);
assign AND     = (op==6'b000000) & (sa==5'b00000) & (func==6'b100100);
assign ANDI    = (op==6'b001100);
assign BEQ     = (op==6'b000100);
assign BGEZ    = (op==6'b000001) & (rt==5'b00001);
assign BGEZAL  = (op==6'b000001) & (rt==5'b10001);
assign BGTZ    = (op==6'b000111) & (rt==5'b00000);
assign BLEZ    = (op==6'b000110) & (rt==5'b00000);
assign BLTZ    = (op==6'b000001) & (rt==5'b00000);
assign BLTZAL  = (op==6'b000001) & (rt==5'b10000);
assign BNE     = (op==6'b000101);
assign BREAK   = (op==6'b000000) & (func==6'b001101);
assign DIV     = (op==6'b000000) & (rd==5'b00000) & (sa==5'b00000) & (func==6'b011010);
assign DIVU    = (op==6'b000000) & (rd==5'b00000) & (sa==5'b00000) & (func==6'b011011);
assign ERET    = ({op,rs,rt,rd,sa,func} == 32'b010000_1000_0000_0000_0000_0000_011000);
assign J       = (op==6'b000010);
assign JAL     = (op==6'b000011);
assign JALR    = (op==6'b000000) & (rt==5'b00000) & (sa==5'b00000) & (func==6'b001001);
assign JR      = (op==6'b000000) & ({rt,rd,sa}==15'b000000000000000) & (func==6'b001000); 
assign LB      = (op==6'b100000);
assign LBU     = (op==6'b100100);
assign LH      = (op==6'b100001);
assign LHU     = (op==6'b100101);
assign LUI     = (op==6'b001111) & (rs==5'b00000);
assign LW      = (op==6'b100011);
assign LWL     = (op==6'b100010);
assign LWR     = (op==6'b100110);
assign MFCO    = (op==6'b010000) & (rs==5'b00000) & (sa==5'b00000) & (func[5:3]==3'b000);
assign MFHI    = (op==6'b000000) & ({rs,rt,sa}==15'b000000000000000) & (func==6'b010000);
assign MFLO    = (op==6'b000000) & ({rs,rt,sa}==15'b000000000000000) & (func==6'b010010);
assign MTCO    = (op==6'b010000) & (rs==5'b00100) & (sa==5'b00000) & (func[5:3]==3'b000);
assign MTHI    = (op==6'b000000) & ({rt,rd,sa} == 15'b000000000000000) & (func==6'b010001);
assign MTLO    = (op==6'b000000) & ({rt,rd,sa} == 15'b000000000000000) & (func==6'b010011);
assign MULT    = (op==6'b000000) & (rd==5'b00000) & (sa==5'b00000) & (func==6'b011000);
assign MULTU   = (op==6'b000000) & (rd==5'b00000) & (sa==5'b00000) & (func==6'b011001);
assign NOR     = (op==6'b000000) & (sa==5'b00000) & (func==6'b100111);
assign OR      = (op==6'b000000) & (sa==5'b00000) & (func==6'b100101);
assign ORI     = (op==6'b001101);
assign SB      = (op==6'b101000);
assign SH      = (op==6'b101001);
assign SLL     = (op==6'b000000) & (rs==5'b00000) & (func==6'b000000);
assign SLLV    = (op==6'b000000) & (sa==5'b00000) & (func==6'b000100);
assign SLT     = (op==6'b000000) & (sa==5'b00000) & (func==6'b101010);
assign SLTI    = (op==6'b001010);
assign SLTIU   = (op==6'b001011);
assign SLTU    = (op==6'b000000) & (sa==5'b00000) & (func==6'b101011);
assign SRA     = (op==6'b000000) & (rs==5'b00000) & (func==6'b000011);
assign SRAV    = (op==6'b000000) & (sa==5'b00000) & (func==6'b000111);
assign SRL     = (op==6'b000000) & (rs==5'b00000) & (func==6'b000010);
assign SRLV    = (op==6'b000000) & (sa==5'b00000) & (func==6'b000110); 
assign SUB     = (op==6'b000000) & (sa==5'b00000) & (func==6'b100010);
assign SUBU    = (op==6'b000000) & (sa==5'b00000) & (func==6'b100011);
assign SW      = (op==6'b101011);
assign SWL     = (op==6'b101010);
assign SWR     = (op==6'b101110);
assign SYSCALL = (op==6'b000000) & (func==6'b001100);
assign XOR     = (op==6'b000000) & (sa==5'b00000) & (func==6'b100110);
assign XORI    = (op==6'b001110);

always@(posedge clk) begin
    if(rst==1)
      PC <= 32'hbfc00000;
    else if(pipe1_allowin==1)
      PC <= PC_next;
    end



//alu source A
assign ALUSrcA[1] = (MFHI || MFLO)?1:0;
assign ALUSrcA[0] = (SLL||SRA||SRL||MFLO) ? 1:0;
assign rdata1_true = (pipe2_valid && (pipe2_data[16:12] == pipe1_data[25:21]) && pipe2_data[17] == 1'b1 && (pipe2_data[11:9] != 3'b1))?wdata:
					(pipe3_valid && (pipe3_data[20:16] == pipe1_data[25:21]) && pipe3_data[21] == 1'b1 && (pipe3_data[15:13] != 3'b1))?pipe3_data[215:184]:
					(pipe4_valid && (pipe4_data[87:83] == pipe1_data[25:21]) && pipe4_data[82] == 1'b1 && (pipe4_data[81:79] != 3'b1))?pipe4_data[119:88]:
					rdata1;

assign HI_true =    (MFHI && pipe2_data[4])?wdata:
					(MFHI && pipe3_data[7])?pipe3_data[215:184]:
					(MFHI && pipe4_data[74])?pipe4_data[119:88]:
					HI;
assign LO_true =  (MFLO && pipe2_data[3])?wdata:
                  (MFLO && pipe3_data[6])?pipe3_data[215:184]:
                  (MFLO && pipe4_data[73])?pipe4_data[119:88]:
                  LO;

assign data1  = (ALUSrcA == 2'b0)? rdata1_true:
				(ALUSrcA == 2'b1)? sa:
				(ALUSrcA == 2'b10 && m_axis_dout_tvalid)?m_axis_dout_tdata[31:0]:
				(ALUSrcA == 2'b10 && (m_axis_dout_tvalid == 0))?HI_true:
				(ALUSrcA == 2'b11 && m_axis_dout_tvalid)?m_axis_dout_tdata[71:40]:
                (ALUSrcA == 2'b11 && (m_axis_dout_tvalid == 0))?LO_true:0;
                                
				//({32{((pipe4_data[78] | pipe4_data[77]))}}& m_axis_dout_tdata[31:0])||({32{(pipe4_data[76] | pipe4_data[75])}} & mul_result[63:32]): //div mul-----HI
                //({32{(pipe4_data[78] | pipe4_data[77])}}& m_axis_dout_tdata[71:40])||({32{(pipe4_data[76] | pipe4_data[75])}} & mul_result[31:0]); //div mul----- LO
				//m_axis_dout_tdata[31:0]:m_axis_dout_tdata[71:40];
				
				
				/* && m_axis_dout_tvalid)? :
				(ALUSrcA == 2'b10 && (pipe4_data[76] | pipe4_data[75]))? mul_result[63:32]:
				(ALUSrcA == 2'b11 && m_axis_dout_tvalid)? m_axis_dout_tdata[71:40]:
				(ALUSrcA == 2'b11 && (pipe4_data[76] | pipe4_data[75]))? mul_result[31:0]:
				0;*/
				
				
				
				
				
				//(ALUSrcA == 2'b11)? LO:;

//alu source B
assign ALUSrcB[2] = (MFHI || MFLO || MTHI || MTLO)?1:0;
assign ALUSrcB[1] = (LUI || ORI || XORI || ANDI)?1:0;
assign ALUSrcB[0] = (SW||LW||ADDIU||SLTI||SLTIU||LUI||ADDI)?1:0;



assign rdata2_true = (pipe2_valid && (pipe2_data[16:12] == pipe1_data[20:16]) && pipe2_data[17] == 1'b1 && (pipe2_data[11:9] != 3'b1))?wdata:
				(pipe3_valid && (pipe3_data[20:16] == pipe1_data[20:16]) && pipe3_data[21] == 1'b1 && (pipe3_data[15:13] != 3'b1))?pipe3_data[215:184]:
				(pipe4_valid && (pipe4_data[87:83] == pipe1_data[20:16]) && pipe4_data[82] == 1'b1 && (pipe4_data[81:79] != 3'b1))?pipe4_data[119:88]:
				rdata2;

assign data2      =({32{ALUSrcB==3'd0}} & rdata2_true)
		         | ({32{ALUSrcB==3'd1}} & sign_extension)
		         | ({32{ALUSrcB==3'd2}} & zero_extension)		   
		         | ({32{ALUSrcB==3'd3}} & extension_zero)
		         | ({32{ALUSrcB==3'd4}} & 32'b0);//LUI data

//alu source B2
assign ALUSrcB2 =   (
					(BNE && !zero)
					|| (BEQ && zero) 
					|| (BGEZ && ~rdata1_true[31]) 
					|| (BGTZ && ~rdata1_true[31] && (rdata1_true | 32'b0))
					|| (BLEZ && (rdata1_true[31] || rdata1_true == 32'b0))
					|| (BLTZ && rdata1_true[31])
					|| (BLTZAL && rdata1_true[31])
					|| (BGEZAL && ~rdata1_true[31])
					)?1:0;

assign offset   = (ALUSrcB2==0)?4:shift_imm_left_2;//4 or shiftimmediate
//alu control	   
assign alu_control = ({4{AND==1||ANDI==1}} & 4'b0000)
                   | ({4{OR==1 || ORI==1}} & 4'b0001)
				   | ({4{SW==1 || LW==1 || ADDU==1 || ADDIU==1 ||ADD==1 ||ADDI==1 ||MFHI==1 ||MFLO==1 ||MTHI==1 ||MTLO==1 }} & 4'b0010)
				   | ({4{SLTIU==1 || SLTU==1 || SUB==1 || SUBU==1}} & 4'b0011)
				   | ({4{SLT==1 || SLTI==1}} & 4'b0100)
				   | ({4{NOR==1}} & 4'b0101)
				   | ({4{XOR==1 || XORI==1}} & 4'b0110)
				   | ({4{SLL==1 || SLLV==1}} & 4'b0111)
				   | ({4{SRL==1 || SRLV==1}} & 4'b1000)
				   | ({4{SRA==1 || SRAV==1}} & 4'b1001);
				
 assign inst_sram_en    = 1;
 assign inst_sram_wen   = 4'b0000;
 assign inst_sram_wdata = 32'b0;
 
 assign Mem_en   = (SW || LW)?1:0;
 assign Mem_wen  = (SW)?4'b1111:4'b0000;
 assign PCSrc[1] = (JR || JALR)?1:0;
 assign PCSrc[0] = (J || JAL || JALR)?1:0;
 //to avoid processing the first instruction twice
 assign PC_next  = (PC==32'hbfc00000)?PC+4:
                  ({32{PCSrc == 0}} & alu_result2) //pc+4  pc+sign_extend(off<<2) 
                | ({32{PCSrc == 1}} & J_address)  //J address
			    | ({32{PCSrc == 2}} & data1)     //JR address
			    | ({32{PCSrc == 3}} & rdata1_true);         //JARL address

assign RegWrite  = (LW || ADDU || SLTU || NOR || XOR || XORI|| SRA || SRAV || SRL || SRLV || SLLV || OR || SLT|| SLL || AND || ANDI || ADDIU || JAL || LUI || SLL || SUB || SUBU || SLTI || ADDI || SLTIU || ADD || ORI || BLTZAL || BGEZAL || JALR || MFHI || MFLO)?1:0;
assign RegDst[1] = (JAL || BLTZAL || BGEZAL || JALR)?1:0;
assign RegDst[0] = (ADDU || OR || SLT|| SLL || SLLV || SRL || SRLV || SRA || SRAV || ADD || SUB || SUBU || SLTU || AND || NOR || XOR || JALR || MFLO || MFHI)?1:0;
assign waddr=({5{RegDst==2'd0}} & pipe1_data[20:16])
           | ({5{RegDst==2'd1}} & pipe1_data[15:11])
		   | ({5{RegDst==2'd2}} & 5'd31)   //JAL BLTZAL BGEZAL 
		   | ({5{RegDst==2'd3}} & pipe1_data[15:11]); //JALR rd<-pc+8
		   
assign MemtoReg[2] = (JAL || BLTZAL || BGEZAL || JALR)?1:0;
assign MemtoReg[1] = (SLTIU ||LUI || SLTU)?1:0;
assign MemtoReg[0] = (SLTIU ||LW || SLTU)?1:0;

/*----------------------------pipe1----------------------------*/

 //reg valid_in;
 /*always@(posedge clk)
 begin
 if (rst)
  begin
   valid_in<=1'b0;
  end
 else
  begin
   valid_in<=1'b1;
  end
 end*/


assign valid_in=1;
/*
assign pipe1_ready_go=!(( (pipe2_valid && (pipe2_data[16:12])) && (pipe2_data[17:17]) && ((pipe1_data[25:21]==pipe2_data[16:12]) || (pipe1_data[20:16]==pipe2_data[16:12])) ) 
                      || ( (pipe3_valid && (pipe3_data[20:16])) && (pipe3_data[21:21]) && ((pipe1_data[25:21]==pipe3_data[20:16]) || (pipe1_data[20:16]==pipe3_data[20:16])) ) 
                      || ( (pipe4_valid && (pipe4_data[87:83])) && (pipe4_data[82:82]) && ((pipe1_data[25:21]==pipe4_data[87:83]) || (pipe1_data[20:16]==pipe4_data[87:83])) ) );  
*/

assign pipe1_ready_go = !(( pipe2_valid && pipe2_data[11: 9] == 3'b1 && (pipe2_data[16:12] == rs || pipe2_data[16:12] == rt))
						||( pipe3_valid && pipe3_data[15:13] == 3'b1 && (pipe3_data[20:16] == rs || pipe3_data[20:16] == rt))
						||( pipe4_valid && pipe4_data[81:79] == 3'b1 && (pipe4_data[87:83] == rs || pipe4_data[87:83] == rt)) 
						||( (MFHI || MFLO ) && ( pipe2_valid && (pipe2_data[8:5] != 4'b0)))
						||( (MFHI || MFLO ) && ( pipe3_valid && (pipe3_data[11:8] != 4'b0)))
						||( (MFHI || MFLO ) && ( pipe4_valid && (pipe4_data[78:75] != 4'b0)))
						||( (MFHI || MFLO || ADD || ADDU ||ADDI ||ADDIU || ADDU || AND || ANDI || BEQ || BGEZ || BGEZAL || BGTZ || BLEZ || BLTZ 
						    || BLTZAL || BNE || JAL || JALR || LB || LBU || LH || LHU || LUI || LW || LWL || LWR 
						    || MFCO || MTCO || MTHI || MTLO || NOR || OR || ORI || SB || SH || SLL || SLLV || SLT || SLTI
						    || SLTIU || SLTU || SRA || SRAV || SRL || SRLV || SUB || SUBU || SW || SWL || SWR || XOR || XORI ) && (pipe2_data[8:7]!=2'b0) && (m_axis_dout_tvalid == 0)));
						//||( (DIV  || DIVU)  && (m_axis_dout_tvalid == 0)));
						//||ADDIU || ADDU || AND || ANDI || BEQ || BGEZ || BGEZAL || BGTZ || BLEZ || BLTZ 
                                                    // || BLTZAL || BNE || BREAK || ERET || J || JAL || JALR || JR || LB || LBU || LH || LHU || LUI || LW || LWL || LWR 
                                                     //|| MFCO || MFHI || MFLO || MTCO || MTHI || MTLO || NOR || OR || ORI || SB || SH || SLL || SLLV || SLT || SLTI
                                                     //|| SLTIU || SLTU || SRA || SRAV || SRL || SRLV || SUB || SUBU || SW || SWL || SWR || XOR || XORI 

//assign pipe1_ready_go=!(( (pipe1_valid && (waddr)) && (RegWrite) && ((Instruction[25:21]==waddr) || (Instruction[20:16]==waddr)) ) 
  //                    || ( (pipe2_valid && (pipe2_data[16:12])) && (pipe2_data[17:17]) && ((Instruction[25:21]==pipe2_data[16:12]) || (Instruction[20:16]==pipe2_data[16:12])) ) 
    //                  || ( (pipe3_valid && (pipe3_data[20:16])) && (pipe3_data[21:21]) && ((Instruction[25:21]==pipe3_data[20:16]) || (Instruction[20:16]==pipe3_data[20:16])) ) );
                      
 assign pipe1_allowin        = !pipe1_valid || pipe1_ready_go && pipe2_allowin;
 assign pipe1_to_pipe2_valid = pipe1_valid && pipe1_ready_go;
 assign Instruction          = inst_sram_rdata;

always @(posedge clk) begin
     if(rst) begin
	     pipe1_valid <= 1'b0;
	 end
	 else if(pipe1_allowin) begin
	     pipe1_valid <= valid_in;
	 end
	 if(valid_in && pipe1_allowin) begin
	     pipe1_data[95:64] <= PC;
	     pipe1_data[63:32] <= PC+8;
		 pipe1_data[31: 0] <= Instruction;
	 end
end 
			  
/*----------------------------pipe2----------------------------*/
 assign pipe2_ready_go       = pipe2_valid;
 assign pipe2_allowin        = !pipe2_valid || (pipe2_ready_go && pipe3_allowin);
 assign pipe2_to_pipe3_valid = pipe2_valid && pipe2_ready_go;
 
 always @(posedge clk) begin
     if(rst) begin
	     pipe2_valid<=1'b0;
	   end
	 else if(pipe2_allowin) begin
	     pipe2_valid<=pipe1_to_pipe2_valid;
	   end
	 if(pipe1_to_pipe2_valid && pipe2_allowin) begin
	     pipe2_data[183:152] <= rdata2_true;            //rdata2 for SW and LW
	     pipe2_data[151:120] <= pipe1_data[95:64]; //PC
	     pipe2_data[119: 88] <= pipe1_data[63:32]; //PC+8
		 pipe2_data[ 87: 56] <= data1;             //ALU1 data1
		 pipe2_data[ 55: 24] <= data2;              //ALU1 data2
		 pipe2_data[ 23: 20] <= alu_control;
		 pipe2_data[ 19: 19] <= Mem_en;
		 pipe2_data[ 18: 18] <= Mem_wen;
		 pipe2_data[ 17: 17] <= RegWrite;
		 pipe2_data[ 16: 12] <= waddr;
		 pipe2_data[ 11:  9] <= MemtoReg;
		 pipe2_data[  8:  5] <= {DIV, DIVU, MULT, MULTU};
		 pipe2_data[  4:  3] <= {MTHI, MTLO};
		 pipe2_data[  2:  0] <= 0;
	 end 
 end
 
assign exe_pc = pipe2_data[151:120];

assign wdata=({32{pipe2_data[11: 9]==3'd0}} & alu_result1)//ALUresult1   
           //| ({32{pipe2_data[11: 9]==3'd1}} & Read_data)
		   | ({32{pipe2_data[11: 9]==3'd2}} & pipe2_data[55:24])
		   | ({32{pipe2_data[11: 9]==3'd3}} & carryout)//slt(Carryout)
		   | ({32{pipe2_data[11: 9]==3'd4}} & pipe2_data[119:88]);//PC+8

//assign Address=pipe3_data[87:56];
assign Address       = alu_result1;
//assign Write_data=pipe3_data[55:24];
assign Write_data    = pipe2_data[183:152];//[183:152]->[55:24]
//assign data_sram_en=pipe3_data[23:23];
assign data_sram_en  = pipe2_data[19:19];
//assign data_sram_wen=pipe3_data[22:22];
assign data_sram_wen = {4{pipe2_data[18:18]}};
 
/*----------------------------pipe3----------------------------*/
 assign pipe3_ready_go       = pipe3_valid;
 assign pipe3_allowin        = !pipe3_valid || (pipe3_ready_go && pipe4_allowin);
 assign pipe3_to_pipe4_valid = pipe3_valid && pipe3_ready_go;
 
 always @(posedge clk) begin
     if(rst) begin
	     pipe3_valid <= 1'b0;
	   end
	 else if(pipe3_allowin) begin
	     pipe3_valid <= pipe2_to_pipe3_valid;
	   end
	 if(pipe2_to_pipe3_valid && pipe3_allowin) begin
	 	 pipe3_data[215:184] <= wdata; //wdata from alu
	     pipe3_data[183:152] <= pipe2_data[183:152];//rdata2 for SW
	     pipe3_data[151:120] <= pipe2_data[151:120];//PC
	     pipe3_data[119: 88] <= pipe2_data[119:88]; //PC+8
		 pipe3_data[ 87: 56] <= alu_result1;         //Address
		 pipe3_data[ 55: 24] <= pipe2_data[55:24];  //data2, probably data_ram write data
		 pipe3_data[ 23: 23] <= pipe2_data[19:19];  //data_sram_en
		 pipe3_data[ 22: 22] <= pipe2_data[18:18];  //data_sram_wen
		 pipe3_data[ 21: 21] <= pipe2_data[17:17];  //RegWrite
		 pipe3_data[ 20: 16] <= pipe2_data[16:12];  //waddr
		 pipe3_data[ 15: 13] <= pipe2_data[11:9];   //MemtoReg
		 pipe3_data[ 12: 12] <= carryout;
		 pipe3_data[ 11:  8] <= pipe2_data[8:5]; //DIV, DIVU, MULT, MULTU
		 pipe3_data[  7:  6] <= pipe2_data[4:3]; //MTHI MTLO
		 pipe3_data[  5:  0] <= 0;
	   end
 end

assign mem_pc = pipe3_data[151:120];

/*
assign wdata=({32{pipe3_data[15:13]==3'd0}} & pipe3_data[87:56])//ALUresult1
           | ({32{pipe3_data[15:13]==3'd1}} & Read_data)
		   | ({32{pipe3_data[15:13]==3'd2}} & pipe3_data[55:24])
		   | ({32{pipe3_data[15:13]==3'd3}} & pipe3_data[12:12])//slt(Carryout)
		   | ({32{pipe3_data[15:13]==3'd4}} & pipe3_data[119:88]);//PC+8
*/
wire [31: 0] wdata_final;
assign wdata_final = (pipe3_data[15:13]==3'd1)? Read_data: pipe3_data[215:184];
 
/*----------------------------pipe4----------------------------*/
 //wire valid_out;
 //wire [WIDTH-1:0] data_out;
 assign pipe4_ready_go=pipe4_valid;
 assign pipe4_allowin=!pipe4_valid || pipe4_ready_go /*&& out_allow*/;
 always @(posedge clk)
 begin
     if(rst) begin
	     pipe4_valid <= 1'b0;
	   end
	 else if(pipe4_allowin) begin
	     pipe4_valid <= pipe3_to_pipe4_valid;
	   end
	 if(pipe3_to_pipe4_valid && pipe4_allowin) begin
	     pipe4_data[151:120] <= pipe3_data[151:120];//PC
	     pipe4_data[119: 88] <= wdata_final;              //wdata
		 pipe4_data[ 87: 83] <= pipe3_data[ 20: 16];//waddr
		 pipe4_data[ 82: 82] <= pipe3_data[ 21: 21];//RegWrite
		 pipe4_data[ 81: 79] <= pipe3_data[ 15: 13];//memtoreg to memorize if is lw
		 pipe4_data[ 78: 75] <= pipe3_data[ 11:  8]; ////DIV, DIVU, MULT, MULTU
		 pipe4_data[ 74: 73] <= pipe3_data[  7:  6]; // MTHI MTLO
		 pipe4_data[ 72:  0] <= 0;
	   end 
 end 
 //assign valid_out=pipe4_valid && pipe4_ready_go;
 //assign data_out=pipe4_data;


//debug
assign wb_pc = pipe4_data[151:120];

//Interface
assign rst               = ~resetn;
assign inst_sram_addr    = (rst)?PC:(pipe1_ready_go==0)?PC:PC_next;
assign data_sram_addr    = Address;
assign data_sram_wdata   = Write_data;
assign Read_data         = data_sram_rdata;
assign debug_wb_rf_wnum  = pipe4_data[87:83];
assign debug_wb_rf_wdata = pipe4_data[119:88];
assign debug_wb_pc       = pipe4_data[151:120];
//assign debug_wb_rf_wen={4{pipe4_data[82:82]}};
assign debug_wb_rf_wen={4{wb_RegWrite}};	

//LO HI
always @(posedge clk) begin
	if (rst) begin
		HI <= 32'b0;		
	end
	else if (pipe4_data[74]) begin
		HI <= pipe4_data[119:88];   //MTHI
	end
	else if (pipe4_data[76] || pipe4_data[75]) begin
	    HI <= mul_result[63:32];  //MUL
	end
	else if ((pipe4_data[78] || pipe4_data[77]) && m_axis_dout_tvalid) begin
		HI <= m_axis_dout_tdata[31:0];  //DIV
	end
end
/*
wire [31:0] debug_mul_result;
wire [31:0] debug_div_result;
wire [31:0] debug_write_LO;
wire [3:0] signal;
assign signal = pipe4_data[76:73];
assign debug_mul_result = mul_result[31:0];
assign debug_div_result = m_axis_dout_tdata[71:40];
assign debug_write_LO = pipe4_data[119:88];
*/
always @(posedge clk) begin
	if (rst) begin
		LO <= 32'b0;
		
	end
	else if (pipe4_data[73]) begin
		LO <= pipe4_data[119:88]; //MTLO
	end
	else if (pipe4_data[76] || pipe4_data[75]) begin
	    LO <= mul_result[31:0];  //MUL
	end
	else if ((pipe4_data[78] || pipe4_data[77]) && m_axis_dout_tvalid) begin
		LO <= m_axis_dout_tdata[71:40];  //DIV
	end
end
//-----------------------------------------------------------------------------------------------------------

//regfile
/*regfile r(
	.clk(clk),
	.rst(rst),
	.waddr(pipe4_data[87:83]),
	.raddr1(pipe1_data[25:21]),
	.raddr2(pipe1_data[20:16]),
	.wen(pipe4_data[82:82]),
	.wdata(pipe4_data[119:88]),
	.rdata1(rdata1),
	.rdata2(rdata2)
);*/
regfile r(
	.clk(clk),
	.rst(rst),
	.waddr(pipe4_data[87:83]),
	.raddr1(pipe1_data[25:21]),
	.raddr2(pipe1_data[20:16]),
	.wen(wb_RegWrite),
	.wdata(pipe4_data[119:88]),
	.rdata1(rdata1),
	.rdata2(rdata2)
);


//ALU

//execute: alu
alu a1(
	.A(pipe2_data[87:56]),
	.B(pipe2_data[55:24]),
	.ALUop(pipe2_data[23:20]),
	.Overflow(overflow),
	.CarryOut(carryout),
	.Zero(),
    .Result(alu_result1)
);

//PC+offset: alu
alu a2(
	.A(PC),
	.B(offset),
	.ALUop(4'b0010),
	.Overflow(),
	.CarryOut(),
	.Zero(),
    .Result(alu_result2)
);

//sign extension: alu
alu a3(
	.A(rdata1_true),
	.B(rdata2_true),
	.ALUop(4'b0011),
	.Overflow(),
	.CarryOut(),
	.Zero(zero),
    .Result()
);
//sent out at 3 stage, comback at 5 
assign mul_a = ({33{pipe2_data[6]}} & {pipe2_data[87],pipe2_data[87:56]}) | ({33{pipe2_data[5]}} & {1'b0,pipe2_data[87:56]});
assign mul_b = ({33{pipe2_data[6]}} & {pipe2_data[55],pipe2_data[55:24]}) | ({33{pipe2_data[5]}} & {1'b0,pipe2_data[55:24]});

mymul mul1(
     .CLK(clk),
     .A(mul_a),
     .B(mul_b),
     .P(mul_result)  
);

always @(posedge clk) begin
	if (rst) begin
		s_axis_divisor_tvalid <= 1'b0;
	end
	else if (DIV || DIVU) begin
        s_axis_divisor_tvalid <= 1'b1;
    end
	else if (s_axis_divisor_tready) begin
		s_axis_divisor_tvalid <= 1'b0;
	end
end

always @(posedge clk) begin
	if (rst) begin
		s_axis_dividend_tvalid <= 1'b0;
	end
	else if (DIV || DIVU) begin
        s_axis_dividend_tvalid <= 1'b1;
    end
	else if (s_axis_divisor_tready) begin
		s_axis_dividend_tvalid <= 1'b0;
	end

end

//assign s_axis_divisor_tdata = ({40{DIV}} & {{8{data2[31]}},data2[31:0]}) | ({40{DIVU}} & {8'b0,data2[31:0]});
//assign s_axis_dividend_tdata = ({40{DIV}} & {{8{data1[31]}},data1[31:0]}) | ({40{DIVU}} & {8'b0,data1[31:0]});


assign s_axis_divisor_tdata = ({40{pipe2_data[8]}} & {{8{pipe2_data[55]}},pipe2_data[55:24]}) | ({40{pipe2_data[7]}} & {8'b0,pipe2_data[55:24]});
assign s_axis_dividend_tdata = ({40{pipe2_data[8]}} & {{8{pipe2_data[87]}},pipe2_data[87:56]}) | ({40{pipe2_data[7]}} & {8'b0,pipe2_data[87:56]});

mydiv div1(
     .s_axis_divisor_tdata    (s_axis_divisor_tdata  ),
     .s_axis_divisor_tready   (s_axis_divisor_tready ),
     .s_axis_divisor_tvalid   (s_axis_divisor_tvalid ),
     .s_axis_dividend_tdata   (s_axis_dividend_tdata ),
     .s_axis_dividend_tready  (s_axis_dividend_tready),
     .s_axis_dividend_tvalid  (s_axis_dividend_tvalid),
     .aclk                    (clk                   ),
     .m_axis_dout_tdata       (m_axis_dout_tdata     ),
     .m_axis_dout_tvalid      (m_axis_dout_tvalid    )
);

endmodule
