

aura:
	make -f sim/verilator/Makefile aura AURA_HOME=$(realpath .)

preprocess:
	make -f sim/verilator/Makefile preprocess AURA_HOME=$(realpath .)

clean:
	rm -r build