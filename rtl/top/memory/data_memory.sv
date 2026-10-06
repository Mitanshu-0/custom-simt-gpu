// Per-lane data memory

`include "../cu_defs.svh"

module data_memory (
    input logic clk, // clock
    input logic memory_read_enable, // load enable
    input logic memory_write_enable, // store enable
    input logic [`WARP_SIZE-1:0] active_lane_mask, // WARP_SIZE = 4 → [3:0], active lanes
    input logic [`LANE_WIDTH-1:0] memory_address [0:`WARP_SIZE-1], // LANE_WIDTH = 32 → [31:0], WARP_SIZE = 4 → lanes [0:3], lane addresses
    input logic [`LANE_WIDTH-1:0] memory_store_data [0:`WARP_SIZE-1], // LANE_WIDTH = 32 → [31:0], WARP_SIZE = 4 → lanes [0:3], lane store data
    output logic [`LANE_WIDTH-1:0] memory_load_data [0:`WARP_SIZE-1] // LANE_WIDTH = 32 → [31:0], WARP_SIZE = 4 → lanes [0:3], lane load data
);
    logic [`LANE_WIDTH-1:0] memory [0:`DMEM_DEPTH-1]; // LANE_WIDTH = 32 → 32-bit words, DMEM_DEPTH = 1024 → 1024 memory locations
    localparam int ADDRESS_INDEX_WIDTH = $clog2(`DMEM_DEPTH); // DMEM_DEPTH = 1024 → ADDRESS_INDEX_WIDTH = 10

    initial begin
        for (int index = 0; index < `DMEM_DEPTH; index++) // DMEM_DEPTH = 1024 → initialize memory locations 0 to 1023
            memory[index] = '0;
        $readmemh("data.mem", memory);
    end

    always_ff @(posedge clk) begin
        if (memory_write_enable) begin
            for (int lane = 0; lane < `WARP_SIZE; lane++) begin // WARP_SIZE = 4 → process lanes 0 to 3
                if (active_lane_mask[lane])
                    memory[memory_address[lane][ADDRESS_INDEX_WIDTH+1:2]] <= memory_store_data[lane];
                    // DMEM_DEPTH = 1024 → ADDRESS_INDEX_WIDTH = 10 → [ADDRESS_INDEX_WIDTH+1:2] = [11:2]
                    // Uses address bits [11:2] to select the 32-bit word to be written.
                    // Bits [1:0] are ignored because each 32-bit word occupies 4 bytes.
                    // The selected memory word is updated with the current lane's store data.
            end
        end
    end

    always_comb begin
        for (int lane = 0; lane < `WARP_SIZE; lane++) begin // WARP_SIZE = 4 → process lanes 0 to 3
            if (memory_read_enable)
                memory_load_data[lane] = memory[memory_address[lane][ADDRESS_INDEX_WIDTH+1:2]];
                // DMEM_DEPTH = 1024 → ADDRESS_INDEX_WIDTH = 10 → [ADDRESS_INDEX_WIDTH+1:2] = [11:2]
                // Uses address bits [11:2] to select the 32-bit word to be read.
                // The selected memory word is returned as load data for this lane.
            else
                memory_load_data[lane] = '0;
        end
    end
endmodule
