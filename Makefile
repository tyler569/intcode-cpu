
.PHONY: all
all: test.mem a.out

a.out: simple.v
	iverilog simple.v

test.mem: test.ica
	./icasm.py <test.ica >test.ic
	./ic2mem.py <test.ic >test.mem

