// Per-warp, per-lane vector register file.

`include "../../cu_defs.svh"

module vector_register_file #(
    parameter int WARP_SIZE_P = `WARP_SIZE,
    parameter int NUM_WARPS_P = `NUM_WARPS,
    parameter int NUM_VREGS_P = `NUM_VREGS,
    parameter int LANE_WIDTH_P = `LANE_WIDTH
) (
    input logic clk,
    input logic rst,
    input logic [`WARP_ID_WIDTH-1:0] read_warp_id,
    input logic [`REG_ID_WIDTH-1:0] source_register_1_id,
    input logic [`REG_ID_WIDTH-1:0] source_register_2_id,
    input logic write_valid,
    input logic [`WARP_ID_WIDTH-1:0] write_warp_id,
    input logic [`REG_ID_WIDTH-1:0] destination_register_id,
    input logic [LANE_WIDTH_P-1:0] write_data [0:WARP_SIZE_P-1],
    input logic [WARP_SIZE_P-1:0] write_mask,
    output logic [LANE_WIDTH_P-1:0] source_register_1_data [0:WARP_SIZE_P-1],
    output logic [LANE_WIDTH_P-1:0] source_register_2_data [0:WARP_SIZE_P-1]
);
    logic [LANE_WIDTH_P-1:0] registers [0:NUM_WARPS_P-1][0:WARP_SIZE_P-1][0:NUM_VREGS_P-1];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int warp_index = 0; warp_index < NUM_WARPS_P; warp_index++) begin
                for (int lane_index = 0; lane_index < WARP_SIZE_P; lane_index++) begin
                    for (int register_index = 0; register_index < NUM_VREGS_P; register_index++)
                        registers[warp_index][lane_index][register_index] <= '0;
                    if (NUM_VREGS_P > 1)
                        registers[warp_index][lane_index][`REG_TID] <= warp_index * WARP_SIZE_P + lane_index;
                end
            end
        end else if (write_valid && (destination_register_id != `REG_ZERO)) begin
            for (int lane_index = 0; lane_index < WARP_SIZE_P; lane_index++) begin
                if (write_mask[lane_index])
                    registers[write_warp_id][lane_index][destination_register_id] <= write_data[lane_index];
            end
        end
    end

    generate
        for (genvar lane = 0; lane < WARP_SIZE_P; lane++) begin : GEN_REGISTER_READ
            always_comb begin
                if (source_register_1_id == `REG_ZERO)
                    source_register_1_data[lane] = '0;
                else
                    source_register_1_data[lane] = registers[read_warp_id][lane][source_register_1_id];

                if (source_register_2_id == `REG_ZERO)
                    source_register_2_data[lane] = '0;
                else
                    source_register_2_data[lane] = registers[read_warp_id][lane][source_register_2_id];
            end
        end
    endgenerate

`ifndef SYNTHESIS
    always_ff @(posedge clk) begin
        if (!rst) begin
            for (int warp_index = 0; warp_index < NUM_WARPS_P; warp_index++) begin
                for (int lane_index = 0; lane_index < WARP_SIZE_P; lane_index++) begin
                    assert (registers[warp_index][lane_index][`REG_ZERO] == '0)
                        else $error("R0 invariant violated in warp %0d lane %0d", warp_index, lane_index);
                end
            end
        end
    end
`endif
endmodule
