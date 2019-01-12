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
from os import getenv
import numpy as np

def main():
	seed = np.random.randint(10000)
	print("Seed for this run is {}".format(seed))
	np.random.seed(seed)
	N = 250
	golden = np.random.randint(100, size=(N,2))
	scb = Scoreboard("Controller")
	PARALLEL_BRD = getenv("IN_ORDER") is None
	test0 = scb.GetTest("Broadcast0" if PARALLEL_BRD else "BroadcastInOrder0")
	test1 = scb.GetTest("Broadcast1" if PARALLEL_BRD else "BroadcastInOrder1")
	st0 = Stacker(N, callbacks=[test0.Get])
	st1 = Stacker(N, callbacks=[test1.Get])
	bg0 = BusGetter(callbacks=[st0.Get])
	bg1 = BusGetter(callbacks=[st1.Get])
	(
		srdy, sack, sdata,
		drdy0, dack0, ddata0,
		drdy1, dack1, ddata1,
	) = CreateBuses([
		(("", "src_rdy",),),
		(("", "src_ack",),),
		(("", "src_data", (2,)),),
		(("", "dst0_rdy",),),
		(("", "dst0_canack",),),
		(("", "dst0_data",),),
		(("", "dst1_rdy",),),
		(("", "dst1_canack",),),
		(("", "dst1_data",),),
	])
	cb0 = [bg0.Get]
	cb1 = [bg1.Get]
	if not PARALLEL_BRD:
		class OrderCheck:
			def __init__(self):
				self.received_diff = 0
			def CbAdd(self, x):
				self.received_diff += 1
			def CbMinus(self, x):
				self.received_diff -= 1
				assert self.received_diff >= 0
		chk = OrderCheck()
		cb0.append(chk.CbAdd)
		cb1.append(chk.CbMinus)
	master = TwoWire.Master(srdy, sack, sdata, ck_ev, A=1, B=2)
	slave0 = TwoWire.Slave(drdy0, dack0, ddata0, ck_ev, callbacks=cb0, A=3, B=8)
	slave1 = TwoWire.Slave(drdy1, dack1, ddata1, ck_ev, callbacks=cb1, A=5, B=8)
	yield rst_out_ev
	yield ck_ev
	def It():
		mv = sdata.values
		for i in golden:
			np.copyto(mv[0], i)
			yield mv

	test0.Expect((golden[:,0,np.newaxis],))
	test1.Expect((golden[:,1,np.newaxis],))
	yield from master.SendIter(It())

	for i in range(10):
		yield ck_ev
	assert st0.is_clean and st1.is_clean
	FinishSim()

rst_out_ev, ck_ev = CreateEvents(["rst_out", "ck_ev"])
RegisterCoroutines([
	main(),
])
