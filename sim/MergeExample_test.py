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

def main():
	seed = np.random.randint(10000)
	print(f"Seed for this run is {seed}")
	np.random.seed(seed)
	N = 250
	golden = np.random.randint(100, size=(N,2))
	scb = Scoreboard("Controller")
	test = scb.GetTest("Merge")
	st = Stacker(N, callbacks=[test.Get])
	bg = BusGetter(callbacks=[st.Get])
	(
		srdy0, sack0, sdata0,
		srdy1, sack1, sdata1,
		drdy, dack, ddata,
	) = CreateBuses([
		(("", "src0_rdy",),),
		(("", "src0_ack",),),
		(("", "src0_data",),),
		(("", "src1_rdy",),),
		(("", "src1_ack",),),
		(("", "src1_data",),),
		(("", "dst_rdy",),),
		(("", "dst_canack",),),
		(("", "dst_data", (2,)),),
	])
	master0 = TwoWire.Master(srdy0, sack0, sdata0, ck_ev, A=1, B=2)
	master1 = TwoWire.Master(srdy1, sack1, sdata1, ck_ev, A=1, B=2)
	slave = TwoWire.Slave(drdy, dack, ddata, ck_ev, callbacks=[bg.Get], A=1, B=3)
	yield rst_out_ev
	yield ck_ev
	def It(target, it):
		for i in it:
			target[0][0] = i
			yield target

	test.Expect((golden,))
	Fork(      master0.SendIter(It(sdata0.values, golden[:,0].flat)))
	yield from master1.SendIter(It(sdata1.values, golden[:,1].flat))

	for i in range(10):
		yield ck_ev
	assert st.is_clean
	FinishSim()

rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
RegisterCoroutines([
	main(),
])
