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


module nextpc_gen(
    input  wire        resetn,

    input  wire [31:0] fe_pc,

    input  wire        de_br_taken,     //1: branch taken, go to the branch target
    input  wire        de_br_is_br,     //1: target is PC+offset
    input  wire        de_br_is_j,      //1: target is PC||offset
    input  wire        de_br_is_jr,     //1: target is GR value
    input  wire [15:0] de_br_offset,    //offset for type "br"
    input  wire [25:0] de_br_index,     //instr_index for type "j"
    input  wire [31:0] de_br_target,    //target for type "jr"

    output wire        inst_sram_en,
    output wire [31:0] inst_sram_addr,

    output wire [31:0] nextpc
);
/* nextPC */
//wire [31:0] PC4;
//assign PC4 = fe_pc + 4;
wire [31:0] sign_ex_left;
assign sign_ex_left = {{14{de_br_offset[15]}},de_br_offset,2'b00};

assign inst_sram_en   = 1;
assign inst_sram_addr = nextpc;

assign nextpc         = (
                        (!resetn)?32'hbfc00000:
                        (de_br_taken & de_br_is_br)?fe_pc + sign_ex_left:// + {14{de_br_offset[15]},de_br_offset,2'b00}://beq bne
                        (de_br_taken & de_br_is_j)?{fe_pc[31:28],de_br_index,2'b00}: //j jal
                        (de_br_taken & de_br_is_jr)?de_br_target: //jr
                        fe_pc+4
                        );



endmodule //nextpc_gen
