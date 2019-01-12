// Copyright (c)
//   2016-2019, Yu-Sheng Lin, johnjohnlys@media.ee.ntu.edu.tw
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
`ifndef __HELPER_SV__
`define __HELPER_SV__

// For defining I/O
`define rdyack_input(name) output logic name``_ack, input name``_rdy
`define rdyack_output(name) output logic name``_rdy, input name``_ack
`define rdyack_logic(name) logic name``_rdy, name``_ack
`define rdyack_connect(port_name, logic_name) .port_name``_rdy(logic_name``_rdy), .port_name``_ack(logic_name``_ack)
`define rdyack_noconnect(port_name) .port_name``_rdy(), .port_name``_ack()
`define valid_input(name) input name``_valid
`define valid_output(name) output logic name``_valid
`define valid_logic(name) logic name``_valid
`define valid_connect(port_name, logic_name) .port_name``_valid(logic_name``_valid)
`define valid_noconnect(port_name) .port_name``_valid()
// For defining parameter
`define p_C(p) parameter _C_``p = $clog2(p)
`define p_C1(p) parameter _C1_``p = $clog2(p+1)
`define p_CC(p) parameter _CC_``p = $clog2($clog2(p))
`define p_C1C(p) parameter _C1C_``p = $clog2($clog2(p)+1)
`define p_CC1(p) parameter _CC1_``p = $clog2($clog2(p+1))
`define p_C1C1(p) parameter _C1C1_``p = $clog2($clog2(p+1)+1)
`define p_S(p) parameter _S_``p = 1<<p

module Forward#(parameter bit FAST = 1)(
	input logic clk,
	input logic rst,
	`rdyack_input(src),
	`rdyack_output(dst)
);
	assign src_ack = src_rdy && (!dst_rdy || (FAST && dst_ack));
	always_ff @(posedge clk or negedge rst) begin
		if (!rst) dst_rdy <= 1'b0;
		else      dst_rdy <= dst_rdy ? (!dst_ack || (FAST && src_rdy)) : src_rdy;
	end
endmodule

module Merge#(parameter N = 2)(
	input  logic [N-1:0] src_rdys,
	output logic [N-1:0] src_acks,
	`rdyack_output(dst)
);
	always_comb begin
		dst_rdy = &src_rdys;
		src_acks = {N{dst_ack}};
	end
endmodule

module Broadcast#(parameter N = 2, parameter [N-1:0] ACK_IMM = '0)(
	input  logic clk,
	input  logic rst,
	`rdyack_input(src),
	output logic [N-1:0] dst_rdys,
	input  logic [N-1:0] dst_acks
);
	logic [N-1:0] got, got_test, got_w, dst_acks_1;
	always_comb begin
		dst_rdys = {N{src_rdy}} & ~got;
		dst_acks_1 = (dst_acks & ~ACK_IMM) | (dst_rdys & ACK_IMM);
		got_test = got | dst_acks_1;
		src_ack = src_rdy && (&got_test);
		got_w = src_ack ? '0 : got_test;
	end
	always_ff @(posedge clk or negedge rst) begin
		if (!rst) got <= '0;
		else got <= got_w;
	end
endmodule

module BroadcastInorder#(parameter N = 2, parameter [N-1:0] ACK_IMM = '0)(
	input logic clk,
	input logic rst,
	`rdyack_input(src),
	output logic [N-1:0] dst_rdys,
	input  logic [N-1:0] dst_acks
);
	logic [N-1:0] cur, dst_acks_1;
	assign dst_rdys = {N{src_rdy}} & cur;
	always_comb begin
		dst_acks_1 = (dst_acks & ~ACK_IMM) | (dst_rdys & ACK_IMM);
		src_ack = dst_acks_1[N-1];
	end
	always_ff @(posedge clk or negedge rst) begin
		if (!rst) cur <= 'b1;
		else if (|dst_acks_1) cur <= {cur[N-2:0], cur[N-1]}; // bit rotate
	end
endmodule

module PauseIf#(parameter bit COND = 1)(
	input logic cond, // Pause the transaction if condition is met by zeroing valid
	`rdyack_input(src),
	`rdyack_output(dst)
);
	always_comb begin
		dst_rdy = (COND == cond) && src_rdy;
		src_ack = dst_ack;
	end
endmodule

module DeleteIf#(parameter bit COND = 1)(
	input logic cond, // Delete the transaction if condition is met by asserting ready and zeroing valid
	`rdyack_input(src),
	`rdyack_output(dst),
	output logic is_delete // Whether the transaction is deleted at this cycle
);
	logic delete;
	always_comb begin
		delete = COND == cond;
		dst_rdy = src_rdy && !delete;
		is_delete = src_rdy && delete;
		src_ack = is_delete || dst_ack;
	end
endmodule

module RepeatIf#(parameter bit COND = 1)(
	input logic cond, // Repeat the transaction if condition is met by zeroing ready
	`rdyack_input(src),
	`rdyack_output(dst),
	output logic is_repeat // Whether this is repeated transaction at this cycle
);
	logic fin;
	assign dst_rdy = src_rdy;
	always_comb begin
		fin = COND != cond;
		src_ack = dst_ack && fin;
		is_repeat = dst_ack && !fin;
	end
endmodule

module Serializer#(
	parameter bit ISLAST_IF = 1,
	parameter bit HOLD_SRC = 1
)(
	input  logic clk,
	input  logic rst,
	`rdyack_input(src),
	`rdyack_output(dst),
	input  logic islast_cond,
	output logic cg_enable,
	output logic counter_reset
);
	/* Visualized signals with wavedrom
	{signal: [
		{name: 'clk', wave: 'p..........'},
		['Full Pipeline',
			{name: 'src_rdy', wave: '01.0.......'},
			{name: 'src_ack', wave: '0.10.......'},
			{name: 'src_dat', wave: 'x2.x.......', data: [3]},
			{name: 'dst_rdy', wave: '0..1......0'},
			{name: 'dst_ack', wave: '0...1010.10'},
			{name: 'dst_dat', wave: 'x..2.2.2..x', data: [2,1,0]},
			{name: 'counter_reset', wave: '0.10.......'},
			{name: 'counter_inc', wave: '0...1010...'},
			{name: 'cg_enable', wave: '0.101010...'},
		],
		{},
		['Hold source',
			{name: 'src_rdy', wave: '0.1.......0'},
			{name: 'src_ack', wave: '0........10'},
			{name: 'src_dat', wave: 'x.2.......x', data: [3]},
			{name: 'dst_rdy', wave: '0..1......0'},
			{name: 'dst_ack', wave: '0...1010.10'},
			{name: 'dst_dat', wave: 'x..2.2.2..x', data: [2,1,0]},
			{name: 'counter_reset', wave: '0.10.......'},
			{name: 'counter_inc', wave: '0...1010...'},
			{name: 'cg_enable', wave: '0.101010...'},
		],
	]}
	*/
	logic counter_inc, fin;
	assign fin = ISLAST_IF == islast_cond;
	assign cg_enable = counter_reset || counter_inc;
	assign counter_inc = dst_ack && !fin;
	generate if (HOLD_SRC) begin: HoldSourceDataDuringLoop
		logic running;
		assign src_ack = dst_ack && fin;
		always_comb begin
			counter_reset = !running && src_rdy;
			dst_rdy = running && src_rdy;
		end
		always_ff @(posedge clk or negedge rst) begin
			if (!rst) running <= 1'b0;
			else      running <= running ? !src_ack : src_rdy;
		end
	end else begin: AcceptSourceDataBeforeLoop
		always_comb begin
			src_ack = src_rdy && (!dst_rdy || (dst_ack && fin));
			counter_reset = src_ack;
		end
		always_ff @(posedge clk or negedge rst) begin
			if (!rst) dst_rdy <= 1'b0;
			else      dst_rdy <= src_rdy || dst_rdy && !(dst_ack && fin);
		end
	end endgenerate
endmodule

module Deserializer#(
	parameter bit ISLAST_IF = 1,
	parameter bit HOLD_SRC = 1
)(
	input  logic clk,
	input  logic rst,
	`rdyack_input(src),
	`rdyack_output(dst),
	input  logic islast_cond,
	output logic load_data,
	output logic counter_reset
);
	/* Visualized signals with wavedrom
	    -> TODO <-
	*/
	logic fin;
	assign fin = ISLAST_IF == islast_cond;
	assign counter_reset = dst_ack && fin;
	generate if (HOLD_SRC) begin: HoldSourceDataAtLastLoop
		always_comb begin
			load_data = !fin && src_rdy;
			dst_rdy = fin && src_rdy;
			src_ack = dst_ack || load_data;
		end
	end else begin: AcceptAllDataBeforeOutput
		always_comb begin
			src_ack = src_rdy && !dst_rdy;
			load_data = src_ack;
		end
		always_ff @(posedge clk or negedge rst) begin
			if (!rst) dst_rdy <= 1'b0;
			else      dst_rdy <= dst_rdy ? !dst_ack : (src_rdy && fin);
		end
	end endgenerate
endmodule

module Semaphore#(parameter N_MAX = 63, `p_C1(N_MAX))(
	input  logic clk,
	input  logic rst,
	input  logic i_inc,
	input  logic i_dec,
	output logic o_full,
	output logic o_empty,
	output logic o_will_full,
	output logic o_will_empty,
	output logic [_C1_N_MAX-1:0] o_n
);
	logic [_C1_N_MAX-1:0] o_n_w;
	always_comb begin
		o_full = o_n == N_MAX;
		o_empty = o_n == '0;
	end
	always_comb begin
		case ({i_inc,i_dec})
			2'b10:        o_n_w = o_n + 'b1;
			2'b01:        o_n_w = o_n - 'b1;
			2'b11, 2'b00: o_n_w = o_n;
		endcase
		o_will_full = o_n_w == N_MAX;
		o_will_empty = o_n_w == '0;
	end
	always_ff @(posedge clk or negedge rst) begin
		if (!rst) o_n <= '0;
		else if (i_inc ^ i_dec) o_n <= o_n_w;
	end
endmodule

module FlowControl#(parameter N_MAX = 63)(
	input clk,
	input rst,
	`rdyack_input(src),
	`rdyack_output(dst),
	`valid_input(fin),
	`rdyack_input(wait_all)
);
logic sfull, sempty;
Semaphore#(N_MAX) u_sem(
	.clk(clk),
	.rst(rst),
	.i_inc(dst_ack),
	.i_dec(fin_dval),
	.o_full(sfull),
	.o_empty(sempty),
	.o_will_full(),
	.o_will_empty(),
	.o_n()
);
PauseIf#(1) u_pause_full(
	.cond(sfull),
	`rdyack_connect(src, src),
	`rdyack_connect(dst, dst)
);
assign wait_all_ack = wait_all_rdy & sempty;
endmodule

`ifdef __EXAMPLES__
////////////////////////////////////////////////////
// These are examples showing how to use this file.
////////////////////////////////////////////////////
`define rdyack2_output(name) output logic name``_rdy, input name``_canack
`define rdyack2_extra(name) logic name``_ack; assign name``_ack = name``_rdy && name``_canack;

module ForwardExample(
	input  logic       clk,
	input  logic       rst,
	`rdyack_input(src),
	input  logic [7:0] src_data,
	`rdyack2_output(dst),
	output logic [7:0] dst_data
);

`rdyack2_extra(dst);

`ifdef SLOW
  `define S 1
`else
  `define S 0
`endif
Forward#(`S) u_fwd(
	.clk(clk),
	.rst(rst),
	`rdyack_connect(src, src),
	`rdyack_connect(dst, dst)
);

always_ff @(posedge clk or negedge rst) begin
	if (!rst) begin
		dst_data <= '0;
	end else if (src_ack) begin
		dst_data <= src_data;
	end
end

endmodule

module BroadcastExample(
	input  logic       clk,
	input  logic       rst,
	`rdyack_input(src),
	input  logic [7:0] src_data [2],
	`rdyack2_output(dst0),
	output logic [7:0] dst0_data,
	`rdyack2_output(dst1),
	output logic [7:0] dst1_data
);

`rdyack2_extra(dst0);
`rdyack2_extra(dst1);

`ifdef IN_ORDER
	BroadcastInorder
`else
	Broadcast
`endif
#(2) u_brd(
	.clk(clk),
	.rst(rst),
	`rdyack_connect(src, src),
	.dst_rdys({dst1_rdy,dst0_rdy}),
	.dst_acks({dst1_ack,dst0_ack})
);
assign dst0_data = src_data[0];
assign dst1_data = src_data[1];

endmodule

module MergeExample(
	input  logic       clk,
	input  logic       rst,
	`rdyack_input(src0),
	input  logic [7:0] src0_data,
	`rdyack_input(src1),
	input  logic [7:0] src1_data,
	`rdyack2_output(dst),
	output logic [7:0] dst_data [2]
);

`rdyack2_extra(dst);

Merge#(2) u_merge(
	.src_rdys({src1_rdy,src0_rdy}),
	.src_acks({src1_ack,src0_ack}),
	`rdyack_connect(dst, dst)
);
assign dst_data[0] = src0_data;
assign dst_data[1] = src1_data;

endmodule

module SerializerExampleBitSerialize(
	input  logic       clk,
	input  logic       rst,
	`rdyack_input(src),
	input  logic [31:0] src_data,
	`rdyack2_output(dst),
	output logic dst_bit
);
// Input: 3(11),1(1),4(100),5(101)...
// Output: 111100101...
// Doesn't handle zero value

`rdyack2_extra(dst);
logic [31:0] dst_buf_r, dst_buf_1;
logic still_has_bit, cg_enable, counter_reset;
assign dst_bit = dst_buf_r[0];
always_comb begin
	dst_buf_1 = dst_buf_r >> 1;
	still_has_bit = |dst_buf_1;
end

Serializer#(.ISLAST_IF(0), .HOLD_SRC(0)) u_serial(
	.clk(clk),
	.rst(rst),
	`rdyack_connect(src, src),
	`rdyack_connect(dst, dst),
	.islast_cond(still_has_bit),
	.cg_enable(cg_enable),
	.counter_reset(counter_reset)
);

always_ff @(posedge clk or negedge rst) begin
	if (!rst) begin
		dst_buf_r <= '0;
	end else if (cg_enable) begin
		dst_buf_r <= counter_reset ? src_data : dst_buf_1;
	end
end

endmodule

module SerializerExampleRld(
	input  logic       clk,
	input  logic       rst,
	`rdyack_input(src),
	input  logic [7:0] src_data,
	input  logic [1:0] src_run_len,
	`rdyack2_output(dst),
	output logic [7:0] dst_data
);
// Run length decoding
// Input: (a,1) (b,3) (c,0) (d,2)
// Output: 0a000bc0d (Like the sparse coding in JPEG)

`rdyack2_extra(dst);
logic [1:0] dst_counter_r, dst_counter_1;
logic       dst_fin;
logic       cg_enable, counter_reset;
Serializer#(.ISLAST_IF(1), .HOLD_SRC(1)) u_serial(
	.clk(clk),
	.rst(rst),
	`rdyack_connect(src, src),
	`rdyack_connect(dst, dst),
	.islast_cond(dst_fin),
	.cg_enable(cg_enable),
	.counter_reset(counter_reset)
);

always_comb begin
	dst_counter_1 = dst_counter_r + 'b1;
	dst_fin = dst_counter_r == src_run_len;
	dst_data = dst_fin ? src_data : '0;
end

always_ff @(posedge clk or negedge rst) begin
	if (!rst) begin
		dst_counter_r <= '0;
	end else if (cg_enable) begin
		dst_counter_r <= counter_reset ? '0 : dst_counter_1;
	end
end

endmodule

module DeserializerExampleBit2Vec(
	input  logic clk,
	input  logic rst,
	`rdyack_input(src),
	input  logic src_bit,
	`rdyack2_output(dst),
	output logic [3:0] dst_data
);

// Input: 100111011110...
// Output: 4'b1001 4'b1011 4'b0111... (LSB first)
`rdyack2_extra(dst);
logic [1:0] src_counter;
logic [3:0] mask;
/*logic load_data;*/
assign mask = 'b1 << src_counter;
Deserializer#(.ISLAST_IF(1), .HOLD_SRC(0)) u_des(
	.clk(clk),
	.rst(rst),
	`rdyack_connect(src, src),
	`rdyack_connect(dst, dst),
	.islast_cond(src_counter == 'd3),
	.load_data(/*load_data*/), // since load_data == src_ack when HOLD_SRC == 0
	.counter_reset()
);

always_ff @(posedge clk or negedge rst) begin
	if (!rst) begin
		src_counter <= '0;
		dst_data <= '0;
	end else if (src_ack) begin
		src_counter <= src_counter + 'b1;
		dst_data <= (dst_data & ~mask) | ({4{src_bit}} & mask);
	end
end

endmodule

module DeserializerExampleVec2Arr(
	input  logic clk,
	input  logic rst,
	`rdyack_input(src),
	input  logic [7:0] src_data,
	`rdyack2_output(dst),
	output logic [7:0] dst_arr [2]
);

// Input: 2,34,54,5,3,32...
// Output: (2,34),(54,5),(3,32)...
`rdyack2_extra(dst);
logic [7:0] src_buf;
logic load_data, hold;
assign dst_arr[1] = src_data;
Deserializer#(.ISLAST_IF(1), .HOLD_SRC(1)) u_des(
	.clk(clk),
	.rst(rst),
	`rdyack_connect(src, src),
	`rdyack_connect(dst, dst),
	.islast_cond(hold),
	.load_data(load_data),
	.counter_reset()
);

always_ff @(posedge clk or negedge rst) begin
	if (!rst) begin
		hold <= 1'b0;
	end else if (src_ack) begin
		hold <= !hold;
	end
end

always_ff @(posedge clk or negedge rst) begin
	if (!rst) begin
		dst_arr[0] <= '0;
	end else if (load_data) begin
		dst_arr[0] <= src_data;
	end
end

endmodule

`endif

`endif
