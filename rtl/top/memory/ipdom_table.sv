// Static IPDOM metadata generated from the program control-flow graph.
// The table is indexed by byte-addressed branch PC and returns the byte address
// of that branch's immediate post-dominator (reconvergence point).

`include "../cu_defs.svh"

module ipdom_table (
    input  logic [`PC_WIDTH-1:0] branch_program_counter,
    output logic [`PC_WIDTH-1:0] reconvergence_program_counter,
    output logic reconvergence_valid
);
    logic [`PC_WIDTH-1:0] ipdom_memory [0:`IMEM_DEPTH-1];
    logic ipdom_valid_memory [0:`IMEM_DEPTH-1];

    initial begin
        for (int index = 0; index < `IMEM_DEPTH; index++) begin
            ipdom_memory[index] = '0;
            ipdom_valid_memory[index] = 1'b0;
        end
        $readmemh("ipdom.mem", ipdom_memory);
        $readmemh("ipdom_valid.mem", ipdom_valid_memory);
    end

    always_comb begin
        reconvergence_program_counter = ipdom_memory[branch_program_counter[`PC_WIDTH-1:2]];
        reconvergence_valid = ipdom_valid_memory[branch_program_counter[`PC_WIDTH-1:2]];
    end
endmodule
