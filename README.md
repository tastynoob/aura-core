# aura-core


## develop-env
- vscode
  - [Verilog-HDL/SystemVerilog](https://github.com/mshr-h/vscode-verilog-hdl-support)
- ctags
- [Verible](https://github.com/chipsalliance/verible)
- verilator >= 5.015
- [yosys](https://github.com/YosysHQ/yosys) (with plugin [antmicro/yosys-systemverilog](https://github.com/antmicro/yosys-systemverilog))

## doc
plz see *.drawio.png in doc


## emulation with verilator
```
# compile
export AURA_HOME=`pwd`
make aura # if enable trace: make aura USE_TRACE=1
# for help
./build/aura -h
```

# todo list

## frontend
- ftb
- ftq

## backend
- issue
- fus
- wb

## mem subsystem
