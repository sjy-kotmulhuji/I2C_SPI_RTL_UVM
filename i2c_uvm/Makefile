#vcs -full64 -sverilog -debug_access+all -kdb -lca -ntb_opts uvm-1.2 -timescale=1ns/1ps -o simv ./rtl/counter.sv ./tb/tb_counter.sv
TC ?= apb_rand_test
SEED ?= 1234

VCS_OPTS := -full64 -sverilog
VCS_OPTS += -ntb_opts uvm-1.2
VCS_OPTS += -timescale=1ns/1ps
VCS_OPTS += -debug_access+all -kdb -lca
VCS_OPTS += +incdir+./tb
VCS_OPTS += -cm line+cond+fsm+tgl+branch+assert


SIM_OPTS := +UVM_VERBOSITY=UVM_HIGH
SIM_OPTS += +ntb_random_seed=$(SEED)
#SIM_OPTS += +UVM_TESTNAME=$(TC)
SIM_OPTS += -cm line+cont+fsm+tgl+branch+assert
SIM_OPTS += -cm_dir coverage.vdb
SIM_OPTS += -cm_name sim1

VERDI_OPTS := -covdir coverage.vdb -dbdir simv.daidir -ssf novas.fsdb

.PHONY: compile sim clean

compile:
	vcs $(VCS_OPTS) -f filelist.f -o simv

sim: compile
	./simv  $(SIM_OPTS) 
#+UVM_TESTNAME=apb_write_read_test

#띄어쓰기 하면 안 됨

verdi: sim
	verdi $(VERDI_OPTS)

vw:	sim
	verdi -dbdir simv.daidir -ssf novas.fsdb &

vc:	sim
	verdi -cov -covdir coverage.vdb &


clean:
	rm -rf simv* csrc *.key *.h *.log *.fsdb novas* *.conf *Log *.vdb inter*