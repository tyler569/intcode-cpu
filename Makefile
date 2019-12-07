
.PHONY: all
all: test.mem a.out

a.out: intcpu.v
	iverilog intcpu.v

# test.mem: test.ica
# 	./icasm.py <test.ica >test.ic
# 	./ic2mem.py <test.ic >test.mem

test.mem: 5.ic
	./ic2mem.py <5.ic >test.mem

.PHONY: clean
clean:
	rm -f a.out
	rm -f test.mem
	rm -f test.ic

