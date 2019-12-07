
## intcode in hardware

This project is an implementation of the intcode CPU instruction set from [Advent of Code](https://adventofcode.com) 2019 in an HDL (Hardware Description Language). Specifically, this project uses Verilog to lay out the logic of the CPU in a way that could be synthesized as a physical logic chip.

This CPU can currently run the day 5 challenges, and implements every opcode that has been specified so far in the advent of code challenge (time of writing is day 7).

In practice, this probably can't work on real hardware, mostly because intcode is clearly optimized for software implemenation (requiring division to do opcode decoding is a real pain - those circuits are large and slow in silicon).

Still, I think it's interesting to see how this might be impelemnted if it were.

If you're interested in Verilog resources to try to learn or follow along, here are some links:


### running the CPU

To run this project you will need Icarus Verilog, which provides the compiler and the simulation environment. On my system (Ubuntu 19.10), I was able to install the environment with `sudo apt install iverilog`, the exact command may vary on different systems.

The Makefile provided assembles my day 5 input into a format Verilog can load (Verilog only supports binary or hexadecimal inputs to the readmem function, so I convert the intcode file to hex) and compiles the verilog. Assuming everything worked, you should be able to run the resulting output with `./a.out`.

Here's what that looks like if you don't want to go to the trouble:
```
$ ./a.out
initializing RAM
WARNING: intcpu.v:92: $readmemh(test.mem): Not enough words in the file for the requested range [0:32767].
output: 0
output: 0
output: 0
output: 0
output: 0
output: 0
output: 0
output: 0
output: 0
output: 7259358
halt
```

This is running the day 5 part 1 program, and that output does match my solution.

It's not easy to do interactive input in Verilog, as it's not designed to create programs with user input, so the input device is implemented as a memory mapped I/O decice in the CPU memory space. That device is specified by the IntcodeInputPort module in the Verilog code, and to run day 5 part 2, you just need to change the static 1 to a 5 - (32'h5).

The output port is implemented in the same way, as a memory mapped device, and this means it should be possible to hook multiple of these together to complete day 7, by implementing slightly different versions of the InputPort and OutputPort devices that talk to each other.

### utilities

This project also provides a super-minimal assember, just because I needed one to test the CPU as I was going. It's source is in `icasm.py`, and mainly only substitutes labels for their addresses in the source. `test.ica` is the sample input to this program that I did most of my testing with, and the Makefile can be configured to use that as the program by swapping the test.mem: block for the commented one.
