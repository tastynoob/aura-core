TOP ?= tb
seed ?= 123

ADDITIONAL_PARAM = --x-assign unique --x-initial unique --assert

DEFINES = -DSIMULATION -DDEBUG
WARNING_OFF = -Wno-WIDTH -Wno-PINMISSING -Wno-TIMESCALEMOD -Wno-ENUMVALUE
CXX_FLAGS = -D VTOP=V$(TOP) -D Vname=\\\"$(TOP)\\\"

CXX_SOURCES := $(shell find src -type f -name "*.cpp")
CXX_INCLUDE_PATH := ../inc
SV_INCLUDE_PATH := $(shell find ../../rtl -type d)
SV_INCLUDE_PATH_PARAM := $(addprefix -y ,$(SV_INCLUDE_PATH))


CXX_FLAGS += -I $(CXX_INCLUDE_PATH)
ifeq ($(USE_TRACE),1)
	ADDITIONAL_PARAM += --trace --trace-structs
	DEFINES += -DUSE_TRACE
	CXX_FLAGS += -DUSE_TRACE
endif
ifdef THREAD
	ADDITIONAL_PARAM += --threads $(THREAD)
endif

CXX_FLAGS := --CFLAGS "$(CXX_FLAGS)"

aura: 
	@echo "**********verilator generating**********"
	verilator \
	--cc tb/$(TOP).sv --top-module $(TOP) --exe \
	$(CXX_SOURCES) \
	$(CXX_FLAGS) \
	$(SV_INCLUDE_PATH_PARAM) \
	$(ADDITIONAL_PARAM) \
	$(DEFINES) \
	$(WARNING_OFF) \
	-Mdir build -o aura 

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

clean:
	rm -r build