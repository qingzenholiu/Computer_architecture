/*------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Copyright (c) 2016, Loongson Technology Corporation Limited.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this 
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

3. Neither the name of Loongson Technology Corporation Limited nor the names of 
its contributors may be used to endorse or promote products derived from this 
software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL LOONGSON TECHNOLOGY CORPORATION LIMITED BE LIABLE
TO ANY PARTY FOR DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--------------------------------------------------------------------------------
------------------------------------------------------------------------------*/

`define SIMU_DEBUG

module mycpu_top(
    input  wire        clk,
    input  wire        resetn,            //low active

    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_wen,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata 

  //`ifdef SIMU_DEBUG
   ,output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_wen,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
  //`endif
);

wire [31:0] nextpc;
wire [31:0] fe_pc;
wire [31:0] fe_inst;
wire [ 4:0] de_rf_raddr1;
wire [ 4:0] de_rf_raddr2;
wire [31:0] de_rf_rdata1;
wire [31:0] de_rf_rdata2;
wire        de_br_taken;    
wire        de_br_is_br;    
wire        de_br_is_j;     
wire        de_br_is_jr;    
wire [15:0] de_br_offset;   
wire [25:0] de_br_index;    
wire [31:0] de_br_target;   
wire [10:0] de_out_op;      
wire [ 4:0] de_dest;         
wire [31:0] de_vsrc1;        
wire [31:0] de_vsrc2;        
wire [31:0] de_st_value;
wire [ 2:0] de_ALUctr;
wire [ 2:0] exe_out_op;
wire [ 4:0] exe_dest;
wire [31:0] exe_value;
wire        mem_out_op;
wire [ 4:0] mem_dest;
wire [31:0] mem_value;
wire        wb_rf_wen;
wire [ 4:0] wb_rf_waddr;
wire [31:0] wb_rf_wdata;
wire        pc_enable;
wire        inst_enable;

//pipelinecontrol
wire        fe_ready_go;
wire        fe_validout;
wire        de_ready_go; //I, 1
wire        de_validout; //O, 1
wire        de_allowin;  //O, 1
wire        exe_ready_go; //I 1
wire        exe_validout; //I 1
wire        exe_allowin; //I 1
wire        mem_ready_go; //I 1
wire        mem_validout; //I 1
wire        mem_allowin; //I 1
wire        wb_ready_go; //I 1
wire        wb_validout; //I 1
wire        wb_allowin; //I 1

//`ifdef SIMU_DEBUG
wire [31:0] de_pc;
wire [31:0] de_inst;
wire [31:0] exe_pc;
wire [31:0] exe_inst;
wire [31:0] mem_pc;
wire [31:0] mem_inst;
wire [31:0] wb_pc;
//`endif

// we only need an inst ROM now
assign inst_sram_wen   = 4'b0;
assign inst_sram_wdata = 32'b0;

//ready_go
assign fe_ready_go = 1'b1;
assign de_ready_go = 1'b1;
assign exe_ready_go = 1'b1;
assign mem_ready_go = 1'b1;
assign wb_ready_go = 1'b1;


nextpc_gen nextpc_gen
    (
    .resetn         (resetn         ), //I, 1

    .fe_pc          (fe_pc          ), //I, 32

    .de_br_taken    (de_br_taken    ), //I, 1 
    .de_br_is_br    (de_br_is_br    ), //I, 1
    .de_br_is_j     (de_br_is_j     ), //I, 1
    .de_br_is_jr    (de_br_is_jr    ), //I, 1
    .de_br_offset   (de_br_offset   ), //I, 16
    .de_br_index    (de_br_index    ), //I, 26
    .de_br_target   (de_br_target   ), //I, 32

    .inst_sram_en   (inst_sram_en   ), //O, 1
    .inst_sram_addr (inst_sram_addr ), //O, 32

    .nextpc         (nextpc         )  //O, 32
    );


fetch_stage fe_stage
    (
    .clk            (clk            ), //I, 1
    .resetn         (resetn         ), //I, 1
                                    
    .nextpc         (nextpc         ), //I, 32
                                    
    .inst_sram_rdata(inst_sram_rdata), //I, 32

    .fe_ready_go    (fe_ready_go    ), //I, 1
    .fe_out_allow   (de_allowin     ), //I, 1
    .fe_validout    (fe_validout    ), //O, 1
                                    
    .fe_pc          (fe_pc          ), //O, 32  
    .fe_inst        (fe_inst        )  //O, 32
    );

decode_stage de_stage
    (
    .clk            (clk            ), //I, 1
    .resetn         (resetn         ), //I, 1
    
    .fe_pc          (fe_pc          ), //I, 32                        
    .fe_inst        (fe_inst        ), //I, 32
    //.inst_enable    (inst_enable    ), //I, 1
                                    
    .de_rf_raddr1   (de_rf_raddr1   ), //O, 5
    .de_rf_rdata1   (de_rf_rdata1   ), //I, 32
    .de_rf_raddr2   (de_rf_raddr2   ), //O, 5
    .de_rf_rdata2   (de_rf_rdata2   ), //I, 32

    .fe_validout    (fe_validout    ), //I, 1
    .de_ready_go    (de_ready_go    ), //I, 1
    .de_out_allow   (exe_allowin    ), //I, 1
    .de_validout    (de_validout    ), //O, 1
    .de_allowin     (de_allowin     ), //O, 1
                                    
    .de_br_taken    (de_br_taken    ), //O, 1
    .de_br_is_br    (de_br_is_br    ), //O, 1
    .de_br_is_j     (de_br_is_j     ), //O, 1
    .de_br_is_jr    (de_br_is_jr    ), //O, 1
    .de_br_offset   (de_br_offset   ), //O, 16
    .de_br_index    (de_br_index    ), //O, 26
    .de_br_target   (de_br_target   ), //O, 32
                                    
    .de_out_op      (de_out_op      ), //O, 11
    .de_dest        (de_dest        ), //O, 5 
    .de_vsrc1       (de_vsrc1       ), //O, 32
    .de_vsrc2       (de_vsrc2       ), //O, 32
    .de_st_value    (de_st_value    )  //O, 32
    //.de_ALUctr      (de_ALUctr      )  //O, 3

  //`ifdef SIMU_DEBUG
   
    //.fe_pc          (fe_pc          ), //I, 32
    ,.de_pc          (de_pc          ), //O, 32
    .de_inst        (de_inst        )  //O, 32 
  //`endif
    );


//assign pc_enable    = ;
//assign inst_enable  = ;


execute_stage exe_stage
    (
    .clk            (clk            ), //I, 1
    .resetn         (resetn         ), //I, 1
                                    
    //.de_ALUctr      (de_ALUctr      ), //I, 3
    .de_out_op      (de_out_op      ), //I, 11
    .de_dest        (de_dest        ), //I, 5 
    .de_vsrc1       (de_vsrc1       ), //I, 32
    .de_vsrc2       (de_vsrc2       ), //I, 32
    .de_st_value    (de_st_value    ), //I, 32

    .de_validout    (de_validout    ), //I 1
    .exe_ready_go   (exe_ready_go   ), //I 1
    .exe_out_allow  (mem_allowin    ), //I 1
    .exe_validout   (exe_validout   ), //I 1
    .exe_allowin    (exe_allowin    ), //I 1
                                    
    .exe_out_op     (exe_out_op     ), //O, 3
    .exe_dest       (exe_dest       ), //O, 5
    .exe_value      (exe_value      ), //O, 32

    .data_sram_en   (data_sram_en   ), //O, 1
    .data_sram_wen  (data_sram_wen  ), //O, 4
    .data_sram_addr (data_sram_addr ), //O, 32
    .data_sram_wdata(data_sram_wdata)  //O, 32

  //`ifdef SIMU_DEBUG
   ,.de_pc          (de_pc          ), //I, 32
    .de_inst        (de_inst        ), //I, 32
    .exe_pc         (exe_pc         ), //O, 32
    .exe_inst       (exe_inst       )  //O, 32
  //`endif
    );


memory_stage mem_stage
    (
    .clk            (clk            ), //I, 1
    .resetn         (resetn         ), //I, 1
                                    
    .exe_out_op     (exe_out_op     ), //I, 3
    .exe_dest       (exe_dest       ), //I, 5
    .exe_value      (exe_value      ), //I, 32
                                    
    .data_sram_rdata(data_sram_rdata), //I, 32

    .exe_validout   (exe_validout   ), //I, 1
    .mem_ready_go   (mem_ready_go   ), //I, 1
    .mem_out_allow  (wb_allowin     ), //I, 1
    .mem_validout   (mem_validout   ), //I, 1
    .mem_allowin    (mem_allowin    ), //I, 1
                                    
    .mem_out_op     (mem_out_op     ), //O, 1
    .mem_dest       (mem_dest       ), //O, 5
    .mem_value      (mem_value      )  //O, 32

 // `ifdef SIMU_DEBUG
   ,.exe_pc         (exe_pc         ), //I, 32
    .exe_inst       (exe_inst       ), //I, 32
    .mem_pc         (mem_pc         ), //O, 32
    .mem_inst       (mem_inst       )  //O, 32
  //`endif
    );


writeback_stage wb_stage
    (
    .clk            (clk            ), //I, 1
    .resetn         (resetn         ), //I, 1
                                    
    .mem_out_op     (mem_out_op     ), //I, 1
    .mem_dest       (mem_dest       ), //I, 5
    .mem_value      (mem_value      ), //I, 32

    .mem_validout   (mem_validout   ), //I, 1
    .wb_ready_go    (wb_ready_go    ), //I, 1
    .wb_validout    (wb_validout    ), //I, 1 
    .wb_allowin     (wb_allowin     ), //I, 1
                                    
    .wb_rf_wen      (wb_rf_wen      ), //O, 1
    .wb_rf_waddr    (wb_rf_waddr    ), //O, 5
    .wb_rf_wdata    (wb_rf_wdata    )  //O, 32

  //`ifdef SIMU_DEBUG
   ,.mem_pc         (mem_pc         ), //I, 32
    .mem_inst       (mem_inst       ), //I, 32
    .wb_pc          (wb_pc          )  //O, 32
  //`endif
    );


regfile_2r1w regfile
    (
    .clk    (clk            ), //I, 1
    
    .ra1    (de_rf_raddr1   ), //I, 5
    .rd1    (de_rf_rdata1   ), //O, 32

    .ra2    (de_rf_raddr2   ), //I, 5
    .rd2    (de_rf_rdata2   ), //O, 32

    .we1    (wb_rf_wen      ), //I, 1
    .wa1    (wb_rf_waddr    ), //I, 5
    .wd1    (wb_rf_wdata    )  //O, 32
    );


//`ifdef SIMU_DEBUG
assign debug_wb_pc       = wb_pc;
assign debug_wb_rf_wen   = {4{wb_rf_wen}};
assign debug_wb_rf_wnum  = wb_rf_waddr;
assign debug_wb_rf_wdata = wb_rf_wdata;
//`endif

endmodule //mycpu_top
