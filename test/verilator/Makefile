top = tb
seed ?= 123

DEFINES = -DSIMULATION -DDEBUG
WARNING_OFF = -Wno-WIDTH -Wno-PINMISSING -Wno-TIMESCALEMOD -Wno-ENUMVALUE


CXX_INCLUE_PATH := $(shell find dpic -type f)


INCLUDE_PATH := $(shell find ../../rtl -type d)
INCLUDE_PATH := $(addprefix -y ,$(INCLUDE_PATH))
aura:
	@echo "**********verilator generating**********"
	verilator \
	--cc tb.sv --exe tb.cpp $(CXX_INCLUE_PATH) --top-module $(top) \
	$(INCLUDE_PATH) \
	--x-assign unique --x-initial unique \
	--assert --timing --trace --trace-structs -j \
	$(DEFINES) -Mdir build -o aura \
	$(WARNING_OFF)

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
	@./build/aura +verilator+seed+$(seed) +verilator+rand+reset+2

wave:
	gtkwave wave.vcd

clean:
	rm -r build