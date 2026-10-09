// Memory stage and MEM/WB transfer.

`include "../../cu_defs.svh"

module mem_stage (
    input logic clk,
    input logic rst,
    input logic memory_instruction_valid,
    input logic [`WARP_ID_WIDTH-1:0] memory_warp_id,
    input logic [`PC_WIDTH-1:0] memory_program_counter,
    input logic [`WARP_SIZE-1:0] memory_active_lane_mask,
    input logic [`LANE_WIDTH-1:0] memory_alu_result [0:`WARP_SIZE-1],
    input logic [`LANE_WIDTH-1:0] memory_address [0:`WARP_SIZE-1],
    input logic [`LANE_WIDTH-1:0] memory_store_data [0:`WARP_SIZE-1],
    input logic [`REG_ID_WIDTH-1:0] memory_destination_register_id,
    input logic memory_register_write_enable,
    input logic memory_read_enable,
    input logic memory_write_enable,
    input logic memory_branch_instruction,
    input logic [`WARP_SIZE-1:0] memory_branch_taken_mask,
    input logic [`WARP_SIZE-1:0] memory_branch_fallthrough_mask,
    input logic memory_branch_divergent,
    input logic [`PC_WIDTH-1:0] memory_branch_target_program_counter,
    input logic [`PC_WIDTH-1:0] memory_branch_fallthrough_program_counter,
    input logic [`PC_WIDTH-1:0] memory_branch_reconvergence_program_counter,
    input logic memory_branch_reconvergence_valid,
    input logic memory_exit_instruction,
    input logic [`LANE_WIDTH-1:0] memory_load_data [0:`WARP_SIZE-1],

    output logic [`LANE_WIDTH-1:0] data_memory_address [0:`WARP_SIZE-1],
    output logic [`LANE_WIDTH-1:0] data_memory_store_data [0:`WARP_SIZE-1],
    output logic [`WARP_SIZE-1:0] data_memory_active_lane_mask,
    output logic data_memory_read_enable,
    output logic data_memory_write_enable,

    output logic writeback_instruction_valid,
    output logic [`WARP_ID_WIDTH-1:0] writeback_warp_id,
    output logic [`PC_WIDTH-1:0] writeback_program_counter,
    output logic [`WARP_SIZE-1:0] writeback_active_lane_mask,
    output logic [`LANE_WIDTH-1:0] writeback_result_data [0:`WARP_SIZE-1],
    output logic [`REG_ID_WIDTH-1:0] writeback_destination_register_id,
    output logic writeback_register_write_enable,
    output logic writeback_branch_instruction,
    output logic [`WARP_SIZE-1:0] writeback_branch_taken_mask,
    output logic [`WARP_SIZE-1:0] writeback_branch_fallthrough_mask,
    output logic writeback_branch_divergent,
    output logic [`PC_WIDTH-1:0] writeback_branch_target_program_counter,
    output logic [`PC_WIDTH-1:0] writeback_branch_fallthrough_program_counter,
    output logic [`PC_WIDTH-1:0] writeback_branch_reconvergence_program_counter,
    output logic writeback_branch_reconvergence_valid,
    output logic writeback_exit_instruction
);
    always_comb begin
        data_memory_active_lane_mask = memory_active_lane_mask;
        data_memory_read_enable = memory_instruction_valid && memory_read_enable;
        data_memory_write_enable = memory_instruction_valid && memory_write_enable;
        for (int lane = 0; lane < `WARP_SIZE; lane++) begin
            data_memory_address[lane] = memory_address[lane];
            data_memory_store_data[lane] = memory_store_data[lane];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            writeback_instruction_valid <= 1'b0;
            writeback_warp_id <= '0;
            writeback_program_counter <= '0;
            writeback_active_lane_mask <= '0;
            writeback_destination_register_id <= `REG_ZERO;
            writeback_register_write_enable <= 1'b0;
            writeback_branch_instruction <= 1'b0;
            writeback_branch_taken_mask <= '0;
            writeback_branch_fallthrough_mask <= '0;
            writeback_branch_divergent <= 1'b0;
            writeback_branch_target_program_counter <= '0;
            writeback_branch_fallthrough_program_counter <= '0;
            writeback_branch_reconvergence_program_counter <= '0;
            writeback_branch_reconvergence_valid <= 1'b0;
            writeback_exit_instruction <= 1'b0;
            for (int lane = 0; lane < `WARP_SIZE; lane++)
                writeback_result_data[lane] <= '0;
        end else begin
            writeback_instruction_valid <= memory_instruction_valid;
            writeback_warp_id <= memory_warp_id;
            writeback_program_counter <= memory_program_counter;
            writeback_active_lane_mask <= memory_active_lane_mask;
            writeback_destination_register_id <= memory_destination_register_id;
            writeback_register_write_enable <= memory_instruction_valid && memory_register_write_enable;
            writeback_branch_instruction <= memory_instruction_valid && memory_branch_instruction;
            writeback_branch_taken_mask <= memory_branch_taken_mask;
            writeback_branch_fallthrough_mask <= memory_branch_fallthrough_mask;
            writeback_branch_divergent <= memory_branch_divergent;
            writeback_branch_target_program_counter <= memory_branch_target_program_counter;
            writeback_branch_fallthrough_program_counter <= memory_branch_fallthrough_program_counter;
            writeback_branch_reconvergence_program_counter <= memory_branch_reconvergence_program_counter;
            writeback_branch_reconvergence_valid <= memory_branch_reconvergence_valid;
            writeback_exit_instruction <= memory_instruction_valid && memory_exit_instruction;

            for (int lane = 0; lane < `WARP_SIZE; lane++) begin
                if (memory_read_enable)
                    writeback_result_data[lane] <= memory_load_data[lane];
                else
                    writeback_result_data[lane] <= memory_alu_result[lane];
            end
        end
    end
endmodule
