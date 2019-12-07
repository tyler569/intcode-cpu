
// 
// an intcode CPU
// Inspired by Advent of Code 2019
// Based on github.com/tyler569/simple16
//

module SimpleALU(a, b, op, flags, out, flags_out);
    input[31:0] a, b;
    input[3:0] op;
    input[31:0] flags;

    reg[32:0] acc = 0;

    output[31:0] out;
    output[31:0] flags_out;

    wire of, cf, zf, sf;
    reg ef = 0;

    assign zf = acc[31:0] == 0;
    assign cf = acc[32];
    assign sf = acc[31];
    assign of = acc[32:31] == 2'b01;

    assign out = op == 4'b1011 ? a : acc[31:0];
    assign flags_out = {ef, 11'd0, sf, of, cf, zf};

    always @(*) begin
        case (op)
        4'b0001: acc = a + b;            // add
        4'b0010: acc = a - b;            // sub
        4'b0011: acc = a | b;            // or
        4'b0100: acc = ~(a | b);         // nor
        4'b0101: acc = a & b;            // and
        4'b0110: acc = ~(a & b);         // nand
        4'b0111: acc = a ^ b;            // xor
        4'b1000: acc = ~(a ^ b);         // xnor
        4'b1001: acc = a + b + flags[1]; // adc
        4'b1010: acc = a - b - flags[1]; // sbb
        4'b1011: acc = a - b;            // cmp
        4'b1100: acc = a * b;            // mul
        default: ef = 1;
        endcase
    end
endmodule

// `define RAM_DEBUG

module SimpleRAM(clock, address, data, we, oe);
    parameter SIZE = 2048;

    input clock;
    input[31:0] address;
    input we;
    input oe;

    inout[31:0] data;

    reg[32:0] memory [0:SIZE-1];
    reg[31:0] read;

    // tristate control
    assign data = (address < 32'h0fff && oe && !we) ? read : 32'bz;

    always @ (posedge clock) begin
        if (address < 32'h0FFF && we) begin
            `ifdef RAM_DEBUG
                $display("time: %t, RAM: writing %x (%0d) to %0d",
                    $time, data, data, address);
            `endif
            memory[address] <= data;
        end
    end

    always @ (posedge clock) begin
        if (address < 32'h1000 && !we && oe) begin
            read <= memory[address];
            `ifdef RAM_DEBUG
                $display("time: %t, RAM: reading %0d: got %x (%0d)",
                    $time, address, read, read);
            `endif
        end
    end

    integer k;
    initial begin
        $display("initializing RAM");
        for (k = 0; k < SIZE; k = k + 1)
            memory[k] = 0;

        $readmemh("test.mem", memory);
    end
endmodule

// `define INSTR_DEBUG

module IntcodeDecoder(value, opcode, mode1, mode2, mode3);
    input[31:0] value;
    output[7:0] opcode;
    output mode1;
    output mode2;
    output mode3;

    assign opcode = value % 100;
    assign mode1 = ((value / 100) % 10);
    assign mode2 = ((value / 1000) % 10);
    assign mode3 = ((value / 1000) % 10);

    initial begin
        // $monitor("value: %x, opcode: %x", value, opcode);
    end
endmodule

module SimpleCPU(clock, int, reset, address_bus, ram_write, data_bus);
    input clock;
    input int;
    input reset;

    output reg[31:0] address_bus = 0;
    inout[31:0] data_bus;
    output reg ram_write = 0;

    reg[31:0] alu_a;
    reg[31:0] alu_b;
    reg[3:0] alu_op;
    reg[31:0] alu_flags;
    wire[31:0] alu_flags_out;
    wire[31:0] alu_out;

    reg[31:0] pc;
    reg[31:0] int_vec;

    reg[31:0] instruction;
    reg[7:0] instruction_stage = 0;
    reg next_instr = 1;

    reg[31:0] registers [31:0];
    reg[31:0] flags = 0;

    reg[31:0] data_out_buffer;

    assign data_bus = ram_write ? data_out_buffer : 32'bz;

    SimpleALU alu(alu_a, alu_b, alu_op, alu_flags, alu_out, alu_flags_out);

    wire[7:0] decoded_op;
    wire decoded_mode1;
    wire decoded_mode2;
    wire decoded_mode3;

    IntcodeDecoder idec(instruction, decoded_op, decoded_mode1, decoded_mode2, decoded_mode3);

    always @ (posedge reset) begin
        pc <= 0;
        address_bus <= 0;
        int_vec <= 0;
        next_instr <= 1;
    end

    reg do_jump = 0;
    reg[31:0] jump_to = 0;

    reg decode_cycle = 1;

    `define ZF flags[0]
    `define CF flags[1]
    `define OF flags[2]
    `define SF flags[3]

    always @ (posedge clock) begin
        if (next_instr) begin
            instruction <= data_bus;
        end

        if (ram_write) begin
            ram_write = 0;
        end

        if (decode_cycle) begin
            // nothing to do, let decoder work
            decode_cycle <= 0;
        end else begin
            decode_cycle <= 1;

            // $display("running: %x, mode{1,2}: %x %x", {instruction_stage, decoded_op}, decoded_mode1, decoded_mode2);

            casez ({instruction_stage, decoded_op})
            16'd99: begin
                $display("halt");
                $finish;
            end

            //
            // ADD
            //
            16'h001: begin // add
                address_bus <= pc + 1;
                if (decoded_mode1 == 1) begin
                    instruction_stage <= 2; // immediate mode
                end else begin
                    instruction_stage <= 1; // position mode
                end
                next_instr = 0;
            end

            16'h101: begin
                address_bus <= data_bus;
                instruction_stage <= 2;
            end

            16'h201: begin
                registers[0] <= data_bus;
                address_bus <= pc + 2;
                if (decoded_mode2 == 1) begin
                    instruction_stage <= 4; // immediate mode
                end else begin
                    instruction_stage <= 3; // position mode
                end
            end

            16'h301: begin
                address_bus <= data_bus;
                instruction_stage <= 4;
            end

            16'h401: begin
                registers[1] <= data_bus;
                alu_a <= registers[0];
                alu_b <= data_bus;
                alu_op <= 4'b0001; // +
                address_bus <= pc + 3;
                instruction_stage <= 5;
            end

            16'h501: begin
                registers[2] <= data_bus;
                address_bus <= data_bus; // output position mode (value)
                flags <= alu_flags_out;
                data_out_buffer <= alu_out;
                ram_write <= 1;
                instruction_stage <= 6;
            end

            16'h601: begin
                ram_write <= 0;
                pc = pc + 4;
                next_instr = 1;
            end

            //
            // MULTIPLY
            //
            16'h002: begin
                address_bus <= pc + 1;
                if (decoded_mode1 == 1) begin
                    instruction_stage <= 2; // immediate mode
                end else begin
                    instruction_stage <= 1; // position mode
                end
                next_instr = 0;
            end

            16'h102: begin
                address_bus <= data_bus;
                instruction_stage <= 2;
            end

            16'h202: begin
                registers[0] <= data_bus;
                address_bus <= pc + 2;
                if (decoded_mode2 == 1) begin
                    instruction_stage <= 4; // immediate mode
                end else begin
                    instruction_stage <= 3; // position mode
                end
            end

            16'h302: begin
                address_bus <= data_bus;
                instruction_stage <= 4;
            end

            16'h402: begin
                registers[1] <= data_bus;
                alu_a <= registers[0];
                alu_b <= data_bus;
                alu_op <= 4'b1100; // *
                address_bus <= pc + 3;
                instruction_stage <= 5;
            end

            16'h502: begin
                registers[2] <= data_bus;
                address_bus <= data_bus; // output position mode (value)
                flags <= alu_flags_out;
                data_out_buffer <= alu_out;
                ram_write <= 1;
                instruction_stage <= 6;
            end

            16'h602: begin
                ram_write <= 0;
                pc = pc + 4;
                next_instr = 1;
            end

            //
            // INPUT
            //
            16'h003: begin
                address_bus <= pc + 1;
                next_instr = 0;
                instruction_stage <= 1;
            end

            16'h103: begin
                registers[0] <= data_bus;
                address_bus <= 32'hFFFF0000;
                instruction_stage <= 2;
            end

            16'h203: begin
                registers[1] <= data_bus;
                address_bus <= registers[0];
                instruction_stage <= 3;
            end

            16'h303: begin
                data_out_buffer <= registers[1];
                ram_write <= 1;
                instruction_stage <= 4;
            end

            16'h403: begin
                ram_write <= 0;
                next_instr = 1;
                pc = pc + 2;
            end

            //
            // OUTPUT
            //
            16'h004: begin
                address_bus <= pc + 1;
                if (decoded_mode1 == 0) begin
                    instruction_stage <= 1;
                end else begin
                    instruction_stage <= 2;
                end
                next_instr = 0;
            end

            16'h104: begin
                address_bus <= data_bus; // position mode

                instruction_stage <= 2;
            end

            16'h204: begin
                registers[0] <= data_bus;
                address_bus <= 32'hFFFF0001;
                instruction_stage <= 3;
            end
            
            16'h304: begin
                data_out_buffer <= registers[0];
                ram_write <= 1;
                instruction_stage <= 4;
            end

            16'h404: begin
                ram_write <= 0;
                pc = pc + 2;
                next_instr = 1;
            end

            //
            // ERROR
            //
            default: begin
                $display("error, unsupported op/stage %x",
                    {instruction_stage, decoded_op});
                $finish;
            end
            endcase

            if (next_instr) begin
                instruction_stage <= 0;
                if (do_jump) begin
                    pc <= jump_to;
                    address_bus <= jump_to;
                    do_jump <= 0;
                end else begin
                    address_bus <= pc;
                end
            end
        end // !decode_cycle
    end

    // check flags[3] and jmp to interrupt if set

    initial begin
        // $monitor("a: %b, b: %b, | out: %b, flags: %b", 
        //     alu_a, alu_b, alu_out, alu_flags_out);
        // $monitor("time: %t, instruction: %x; next_instr: %x", $time, instruction, next_instr);
    end
endmodule

module IntcodeInputPort(clock, address_bus, ram_write, data_bus);
    input clock;
    input[31:0] address_bus;
    input ram_write;
    output[31:0] data_bus;

    wire output_enable;
    assign output_enable = address_bus == 32'hFFFF0000;
    assign data_bus = output_enable ? 32'h5 : 32'hz;
endmodule

module IntcodeOutputPort(clock, address_bus, ram_write, data_bus);
    input clock;
    input[31:0] address_bus;
    input ram_write;
    input[31:0] data_bus;

    always @ (posedge clock) begin
        if (ram_write) begin
            case (address_bus)
            32'hFFFF0001:
                $display("output: %0d", data_bus);
            endcase
        end
    end
endmodule

module main;
    wire[31:0] address_bus;
    wire[31:0] data_bus;

    wire ram_write;

    reg cpu_clock_enable = 0;
    reg ram_clock_enable = 0;
    reg main_clk = 0;

    always #5 main_clk = ~main_clk;

    wire ram_clock, cpu_clock;

    and (ram_clock, ram_clock_enable, main_clk);
    and #(2, 2) (cpu_clock, cpu_clock_enable, main_clk);

    pullup pu_addr[31:0] (address_bus); 
    pullup pu_data[31:0] (data_bus);

    SimpleRAM ram0(ram_clock, address_bus, data_bus, ram_write, ~ram_write);

    reg hw_int = 0;
    reg hw_reset = 0;

    SimpleCPU cpu0(
        cpu_clock,
        hw_int,
        hw_reset,
        address_bus,
        ram_write,
        data_bus
    );

    IntcodeOutputPort outport(ram_clock, address_bus, ram_write, data_bus);
    IntcodeInputPort inport(ram_clock, address_bus, ram_write, data_bus);

    initial begin
        // $monitor("time: %t, clk: %b, addr: %b, data: %b",
        //     $time, cpu_clock, address_bus, data_bus);
        hw_reset <= 1;
        #2 hw_reset <= 0;
        ram_clock_enable = 1;
        #18 cpu_clock_enable = 1;
    end
endmodule

