top = tb
seed ?= 123


INCLUDE_PATH := $(shell find ../../rtl -type d)
INCLUDE_PATH := $(addprefix -y ,$(INCLUDE_PATH))
aura:
	@echo "**********verilator generating**********"
	@verilator \
	--cc tb.sv --exe tb.cpp --top-module $(top) \
	$(INCLUDE_PATH) \
	--x-assign unique --x-initial unique \
	--assert --timing --trace -j \
	-DDEBUG -Mdir build -o aura \
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
	@./build/aura +verilator+seed+$(seed) +verilator+rand+reset+2

wave:
	gtkwave wave.vcd

test:
	@echo $(INCLUDE_PATH)

clean:
	rm -r build