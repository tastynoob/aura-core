top = tb
seed = 123

default:
	@echo "**********verilator generating**********"
	@verilator \
	--cc tb.sv --exe tb.cpp --top-module $(top) \
	-y ../../rtl/utils -y ../../rtl/common -y ../..  \
	-Mdir build --x-assign unique --x-initial unique --trace \
	-j --assert --timing \
	-Wno-WIDTH -Wno-PINMISSING -Wno-TIMESCALEMOD

	@if [ $$? -ne 0 ]; then \
		echo "**********verilator generate failed**********"; \
		exit 1; \
	else \
		echo "**********verilator generate successfully**********"; \
	fi

	@echo "**********make building**********"
	@make -C build -f Vtb.mk

	@if [ $$? -ne 0 ]; then \
		echo "**********make build failed**********"; \
		exit 1; \
	else \
		echo "**********make build successfully**********"; \
	fi

run:
	@./build/Vtb +verilator+seed+$(seed) +verilator+rand+reset+2

wave:
	gtkwave wave.vcd