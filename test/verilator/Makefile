gen:
	echo "verilator generating"
	verilator \
		-y ../../src/utils -y ../../src/common -y ../.. \
		--cc tb.sv --exe tb.cpp --top-module tb \
		-Mdir build --x-assign unique --x-initial unique --trace

	if [ $$? -ne 0 ]; then \
		echo "verilator generate failed"; \
		exit 1; \
	else \
		echo "verilator generate successfully"; \
	fi

	echo "make building"
	make -C build -f Vtb.mk

	if [ $$? -ne 0 ]; then \
		echo "make build failed"; \
		exit 1; \
	else \
		echo "make build successfully"; \
	fi

run:
	./build/Vtb +verilator+seed+$(seed) +verilator+rand+reset+2
