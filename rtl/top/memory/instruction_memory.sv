// Synchronous instruction memory

`include "../cu_defs.svh"

module instruction_memory (
    input logic clk, // clock
    input logic [`PC_WIDTH-1:0] address, // PC_WIDTH = 16 → [15:0], instruction byte address
    output logic [`INST_WIDTH-1:0] instruction_data // INST_WIDTH = 32 → [31:0], instruction word
);
    logic [`INST_WIDTH-1:0] memory [0:`IMEM_DEPTH-1]; // INST_WIDTH = 32 → 32-bit instructions, IMEM_DEPTH = 1024 → 1024 instruction locations

    initial begin
        for (int index = 0; index < `IMEM_DEPTH; index++) // IMEM_DEPTH = 1024 → initialize instruction locations 0 to 1023
            memory[index] = '0;
        $readmemh("program.mem", memory); // Load program image
    end

    always_ff @(posedge clk)
        instruction_data <= memory[address[`PC_WIDTH-1:2]];
        // PC_WIDTH = 16 → address[15:2], uses 14 bits as the instruction memory index.
        // Bits [1:0] are ignored because each instruction is 32 bits = 4 bytes.
        // The byte address is therefore converted into a word address by removing the lowest 2 bits.
        // The instruction at the selected memory location is registered on the rising clock edge.
endmodule
