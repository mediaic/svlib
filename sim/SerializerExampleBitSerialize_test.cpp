// Copyright (c)
//   2018-2019, Yu-Sheng Lin, johnjohnlys@media.ee.ntu.edu.tw
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
#include <memory>
#include <iostream>
#include "VSerializerExampleBitSerialize.h"
#include "nicotb_verilator.h"
#ifdef VCD
#include "verilated_vcd_c.h"
typedef VerilatedVcdC DumpType;
#define DUMP_SUFFIX ".vcd"
#else
#include "verilated_lxt2_c.h"
typedef VerilatedLxt2C DumpType;
#define DUMP_SUFFIX ".lxt2"
#endif

int main()
{
	using namespace std;
	namespace NiVe = Nicotb::Verilator;
	constexpr int MAX_SIM_CYCLE = 10000;
	constexpr int SIM_CYCLE_AFTER_STOP = 2;
	int n_sim_cycle = MAX_SIM_CYCLE;
	auto dump_name = "SerializerExampleBitSerialize" DUMP_SUFFIX;
	typedef VSerializerExampleBitSerialize TopType;

	// Init dut and signals
	// TOP is the default name of our macro
	unique_ptr<TopType> TOP(new TopType);
	TOP->eval();
	MAP_SIGNAL(src_rdy);
	MAP_SIGNAL(src_ack);
	MAP_SIGNAL(src_data);
	MAP_SIGNAL(dst_rdy);
	MAP_SIGNAL(dst_canack);
	MAP_SIGNAL(dst_bit);

	// Init events
	NiVe::AddEvent("ck_ev");
	NiVe::AddEvent("rst_out");

	// Init simulation
	vluint64_t sim_time = 0;
	unique_ptr<DumpType> tfp(new DumpType);
	Verilated::traceEverOn(true);
	TOP->trace(tfp.get(), 99);
	tfp->open(dump_name);

	// Simulation
#define Eval TOP->eval();tfp->dump(sim_time++)
#define EvalEvent(e) if ((ret = NiVe::TriggerEvent(e)) != 0) goto cleanup;TOP->eval();NiVe::UpdateWrite();TOP->eval();tfp->dump(sim_time++)
	NiVe::Init();
	const size_t ck_ev = NiVe::GetEventIdx("ck_ev"),
	             rst_out = NiVe::GetEventIdx("rst_out");
	int cycle = 0, ret = 0;
	TOP->clk = 0;
	TOP->rst = 1;
	Eval;
	TOP->rst = 0;
	Eval;
	TOP->rst = 1;
	EvalEvent(rst_out);
	for (
		;
		cycle < n_sim_cycle and not Verilated::gotFinish();
		++cycle
	) {
		TOP->clk = 1;
		EvalEvent(ck_ev);
		TOP->clk = 0;
		Eval;
		if (Nicotb::nicotb_fin_wire) {
			n_sim_cycle = min(cycle + SIM_CYCLE_AFTER_STOP, n_sim_cycle);
		}
	}
cleanup:
	cout << "Simulation stop at timestep " << cycle << endl;
	tfp->close();
	NiVe::Final();
	return ret ? 1 : 0;
}
