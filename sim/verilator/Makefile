TOP ?= tb

ADDITIONAL_PARAM = --x-assign unique --x-initial unique --assert --trace-max-array 64

EMU_DEFINES = -DSIMULATION -DDEBUG
WARNING_OFF = -Wno-WIDTH -Wno-PINMISSING -Wno-TIMESCALEMOD -Wno-ENUMVALUE
CXX_FLAGS = -std=c++20 -DVTOP=V$(TOP) -DVname=\\\"$(TOP)\\\" -DVheader=\\\"V$(TOP).h\\\"

TB_PATH = $(AURA_HOME)/sim/verilator/tb
CXX_SOURCES := $(shell find $(AURA_HOME)/sim/verilator/src -type f -name "*.cpp")
CXX_INCLUDE_PATH := $(AURA_HOME)/sim/verilator/inc
SV_INCLUDE_PATH := $(shell find $(AURA_HOME)/rtl -type d)
SV_INCLUDE_PATH_PARAM := $(addprefix -y ,$(SV_INCLUDE_PATH))


CXX_FLAGS += -I $(CXX_INCLUDE_PATH)
ifeq ($(USE_TRACE),1)
	ADDITIONAL_PARAM += --trace --trace-structs
	EMU_DEFINES += -DUSE_TRACE
	CXX_FLAGS += -DUSE_TRACE
endif
ifdef THREAD
	ADDITIONAL_PARAM += --threads $(THREAD)
endif
CXX_FLAGS := --CFLAGS "$(CXX_FLAGS)"

aura: 
	@echo "**********verilator generating**********"
	verilator \
	--cc $(TB_PATH)/$(TOP).sv --top-module $(TOP) --exe \
	$(CXX_SOURCES) \
	$(CXX_FLAGS) \
	$(SV_INCLUDE_PATH_PARAM) \
	$(ADDITIONAL_PARAM) \
	$(EMU_DEFINES) \
	$(WARNING_OFF) \
	-Mdir $(AURA_HOME)/build -o aura 

	@if [ $$? -ne 0 ]; then \
		echo "**********verilator generate failed**********"; \
		exit 1; \
	else \
		echo "**********verilator generate successfully**********"; \
	fi

	@echo "**********make building**********"
	@make -C $(AURA_HOME)/build -f V$(TOP).mk

	@if [ $$? -ne 0 ]; then \
		echo "**********make build failed**********"; \
		exit 1; \
	else \
		echo "**********make build successfully**********"; \
	fi

preprocess:
	@echo "**********verilator generating**********"
	verilator \
	rtl/cpu/backend/block/intBlock.sv -E \
	$(CXX_SOURCES) \
	$(CXX_FLAGS) \
	$(SV_INCLUDE_PATH_PARAM) \
	$(ADDITIONAL_PARAM) \
	$(EMU_DEFINES) \
	$(WARNING_OFF) \
	-Mdir $(AURA_HOME)/build -o aura 