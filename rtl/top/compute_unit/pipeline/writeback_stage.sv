// Writeback and control feedback.

`include "../../cu_defs.svh"

module writeback_stage (
    input logic writeback_instruction_valid,
    input logic [`WARP_ID_WIDTH-1:0] writeback_warp_id,
    input logic [`PC_WIDTH-1:0] writeback_program_counter,
    input logic [`WARP_SIZE-1:0] writeback_active_lane_mask,
    input logic [`LANE_WIDTH-1:0] writeback_result_data [0:`WARP_SIZE-1],
    input logic [`REG_ID_WIDTH-1:0] writeback_destination_register_id,
    input logic writeback_register_write_enable,
    input logic writeback_branch_instruction,
    input logic [`WARP_SIZE-1:0] writeback_branch_taken_mask,
    input logic [`WARP_SIZE-1:0] writeback_branch_fallthrough_mask,
    input logic writeback_branch_divergent,
    input logic [`PC_WIDTH-1:0] writeback_branch_target_program_counter,
    input logic [`PC_WIDTH-1:0] writeback_branch_fallthrough_program_counter,
    input logic [`PC_WIDTH-1:0] writeback_branch_reconvergence_program_counter,
    input logic writeback_branch_reconvergence_valid,
    input logic writeback_exit_instruction,

    output logic register_file_write_valid,
    output logic [`WARP_ID_WIDTH-1:0] register_file_write_warp_id,
    output logic [`REG_ID_WIDTH-1:0] register_file_write_destination_register_id,
    output logic [`LANE_WIDTH-1:0] register_file_write_data [0:`WARP_SIZE-1],
    output logic [`WARP_SIZE-1:0] register_file_write_mask,

    output logic scoreboard_clear_valid,
    output logic [`WARP_ID_WIDTH-1:0] scoreboard_clear_warp_id,
    output logic [`REG_ID_WIDTH-1:0] scoreboard_clear_destination_register_id,

    output logic branch_commit,
    output logic [`WARP_ID_WIDTH-1:0] branch_warp_id,
    output logic [`WARP_SIZE-1:0] branch_taken_mask,
    output logic [`WARP_SIZE-1:0] branch_fallthrough_mask,
    output logic branch_divergent,
    output logic [`PC_WIDTH-1:0] branch_target_program_counter,
    output logic [`PC_WIDTH-1:0] branch_fallthrough_program_counter,
    output logic [`PC_WIDTH-1:0] branch_reconvergence_program_counter,
    output logic branch_reconvergence_valid,
    output logic [`WARP_SIZE-1:0] branch_active_lane_mask,

    output logic exit_commit,
    output logic [`WARP_ID_WIDTH-1:0] exit_warp_id
);
    always_comb begin
        register_file_write_valid = writeback_instruction_valid &&
                                    writeback_register_write_enable &&
                                    (writeback_destination_register_id != `REG_ZERO);
        register_file_write_warp_id = writeback_warp_id;
        register_file_write_destination_register_id = writeback_destination_register_id;
        register_file_write_mask = writeback_active_lane_mask;

        scoreboard_clear_valid = writeback_instruction_valid &&
                                 writeback_register_write_enable &&
                                 (writeback_destination_register_id != `REG_ZERO);
        scoreboard_clear_warp_id = writeback_warp_id;
        scoreboard_clear_destination_register_id = writeback_destination_register_id;

        branch_commit = writeback_instruction_valid && writeback_branch_instruction;
        branch_warp_id = writeback_warp_id;
        branch_taken_mask = writeback_branch_taken_mask;
        branch_fallthrough_mask = writeback_branch_fallthrough_mask;
        branch_divergent = writeback_branch_divergent;
        branch_target_program_counter = writeback_branch_target_program_counter;
        branch_fallthrough_program_counter = writeback_branch_fallthrough_program_counter;
        branch_reconvergence_program_counter = writeback_branch_reconvergence_program_counter;
        branch_reconvergence_valid = writeback_branch_reconvergence_valid;
        branch_active_lane_mask = writeback_active_lane_mask;

        exit_commit = writeback_instruction_valid && writeback_exit_instruction;
        exit_warp_id = writeback_warp_id;

        for (int lane = 0; lane < `WARP_SIZE; lane++)
            register_file_write_data[lane] = writeback_result_data[lane];
    end
endmodule
