




SV_FILES := $(shell find rtl -name "*.sv*")
SV_PATHS := $(shell find ../../rtl -type d)
SV_PATHS := $(addprefix -I ,$(SV_PATHS))
aura:
	touch temp.v
#convert sv to v
	sv2v -v --skip-preprocessor -E Always $(SV_PATHS) $(SV_FILES) -w temp.v
	yosys -p "plugin -i systemverilog" \
	-p "read_verilog -top tb tb.sv $(SV_FILES)" \
	-p "proc; proc_mux; memory; proc_clean; proc_rmdead; proc_prune; opt; opt_clean; opt_dff; opt_demorgan; opt_dff; opt_expr; opt_mem; opt_muxtree; opt_reduce" \
	-p "show -colors 2 -width -signed -enum -prefix out tb" 
	rm temp.v

tb:
	touch temp.v
	sv2v -v -E Always tb.sv -w temp.v 
	yosys \
	-p "read_verilog -sv temp.v" \
	-p "proc" \
	-p "show -colors 2 -width -signed -enum -prefix out tb"
	#rm temp.v

sv2v:
	touch temp.v
#convert sv to v
	sv2v -v -E Always $(SV_PATHS) $(SV_FILES) -w temp.v