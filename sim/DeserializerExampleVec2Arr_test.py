# Copyright (c)
#   2018-2019, Yu-Sheng Lin, johnjohnlys@media.ee.ntu.edu.tw
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
from nicotb import *
from nicotb.utils import Scoreboard, BusGetter, Stacker
from nicotb.protocol import TwoWire
import numpy as np

def ToArr(i):
	return [((i>>j)&1) for j in range(4)]

def main():
	seed = np.random.randint(10000)
	print(f"Seed for this run is {seed}")
	np.random.seed(seed)
	N = 100
	golden = np.random.randint(4, size=(N,2))
	scb = Scoreboard("Controller")
	test = scb.GetTest("Vec2Arr")
	st = Stacker(golden.shape[0], callbacks=[test.Get])
	bg = BusGetter(callbacks=[st.Get])
	(
		srdy, sack, sdata,
		drdy, dack, ddata,
	) = CreateBuses([
		(("", "src_rdy",),),
		(("", "src_ack",),),
		(("", "src_data"),),
		(("", "dst_rdy",),),
		(("", "dst_canack",),),
		(("", "dst_arr", (2,)),),
	])
	master = TwoWire.Master(srdy, sack, sdata, ck_ev, A=1, B=5)
	slave = TwoWire.Slave(drdy, dack, ddata, ck_ev, callbacks=[bg.Get], A=1, B=2)
	yield rst_out_ev
	yield ck_ev
	def It():
		mv = sdata.values
		for i in golden.flat:
			np.copyto(mv[0], i)
			yield mv

	test.Expect((golden,))
	yield from master.SendIter(It())

	for i in range(100):
		yield ck_ev
	assert st.is_clean
	FinishSim()

rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
RegisterCoroutines([
	main(),
])
