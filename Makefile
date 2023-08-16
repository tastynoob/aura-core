

aura:
	make -f sim/verilator/Makefile aura AURA_HOME=$(realpath .)

clean:
	rm -r build