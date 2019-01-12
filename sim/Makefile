NICOTB=$(shell pwd)/../nicotb/lib
VERI=verilator
PY=python
MKFLAG=-j
NPY_CFLAGS=-I$(shell $(PY) -c "from numpy import get_include as i; print(i())") \
           $(shell $(PY)-config --includes) -DNPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION

all:
	make fwd
	make fwds
	make bwd
	make bwdi
	make merge
	make bitserial
	make rld
	make bit2vec
	make vec2arr

fwd:
	make VF_PATH="Helper.sv" ForwardExample

fwds:
	make VF_PATH="Helper.sv" VERI_FLAGS="-DSLOW" SLOW=1 ForwardExample

bwd:
	make VF_PATH="Helper.sv" BroadcastExample

bwdi:
	make VF_PATH="Helper.sv" VERI_FLAGS="-DIN_ORDER" IN_ORDER=1 BroadcastExample

merge:
	make VF_PATH="Helper.sv" MergeExample

bitserial:
	make VF_PATH="Helper.sv" SerializerExampleBitSerialize

rld:
	make VF_PATH="Helper.sv" SerializerExampleRld

bit2vec:
	make VF_PATH="Helper.sv" DeserializerExampleBit2Vec

vec2arr:
	make VF_PATH="Helper.sv" DeserializerExampleVec2Arr

%: TEST ?= $@_test
%: TOP ?= $@
%: MDIR ?= VOBJ_$(TOP)
%: EXE = V$(TOP)
%: %_test.cpp $(NICOTB)/cpp/nicotb_verilator.so
	-test -z "${COMPILE_ONLY}" && $(VERI) -D__EXAMPLES__ $(VERI_FLAGS) -I../src -cc ../src/$(VF_PATH) \
	 --exe $@_test.cpp $(NICOTB)/cpp/nicotb_verilator.so \
	 --Mdir $(MDIR) --top-module $(TOP) -DVERI_TOP_$(TOP) -D__EXAMPLES__\
	 -CFLAGS "-O1 --std=c++11 $(EXTRA_CFLAGS) $(NPY_CFLAGS) -I$(NICOTB)/cpp"
	make $(MKFLAG) -C $(MDIR) -f $(EXE).mk
	GLOG_logtostderr=1 \
	GLOG_minloglevel=1 \
	PYTHONPATH=$(NICOTB)/python:`pwd` \
	TEST=$(TEST) \
	$(GDB) ./$(MDIR)/$(EXE)

$(NICOTB)/cpp/nicotb_verilator.so:
	make -j -C $(NICOTB)/cpp/

clean:
	rm -rf VOBJ_* *.lxt2 scoreboard.db __pycache__

dump_scoreboard:
	@echo -e \
	".open scoreboard.db\n"\
	".header on\n"\
	".mode column\n"\
	".print ===============\n"\
	".print All Scoreboards\n"\
	".print ===============\n"\
	"select * from Scoreboard;\n"\
	".print\n"\
	".print =========\n"\
	".print All Tests\n"\
	".print =========\n"\
	"select * from Tests;\n"\
	 | sqlite3
