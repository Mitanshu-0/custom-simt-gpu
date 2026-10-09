// Execute stage and lane ALU/branch logic.
// Branches are evaluated independently per active lane so a warp can produce
// separate taken and fall-through masks.

`include "../../cu_defs.svh"

module execute_stage (
    input logic clk,
    input logic rst,
    input logic execute_instruction_valid,
    input logic [`WARP_ID_WIDTH-1:0] execute_warp_id,
    input logic [`PC_WIDTH-1:0] execute_program_counter,
    input logic [`WARP_SIZE-1:0] execute_active_lane_mask,
    input logic [`LANE_WIDTH-1:0] source_register_1_data [0:`WARP_SIZE-1],
    input logic [`LANE_WIDTH-1:0] source_register_2_data [0:`WARP_SIZE-1],
    input logic [`LANE_WIDTH-1:0] execute_immediate_value,
    input logic [`REG_ID_WIDTH-1:0] execute_destination_register_id,
    input logic [5:0] execute_alu_operation,
    input logic execute_uses_immediate_operand,
    input logic execute_register_write_enable,
    input logic execute_memory_read_enable,
    input logic execute_memory_write_enable,
    input logic execute_branch_instruction,
    input logic execute_branch_not_equal,
    input logic execute_exit_instruction,

    output logic memory_instruction_valid,
    output logic [`WARP_ID_WIDTH-1:0] memory_warp_id,
    output logic [`PC_WIDTH-1:0] memory_program_counter,
    output logic [`WARP_SIZE-1:0] memory_active_lane_mask,
    output logic [`LANE_WIDTH-1:0] memory_alu_result [0:`WARP_SIZE-1],
    output logic [`LANE_WIDTH-1:0] memory_address [0:`WARP_SIZE-1],
    output logic [`LANE_WIDTH-1:0] memory_store_data [0:`WARP_SIZE-1],
    output logic [`REG_ID_WIDTH-1:0] memory_destination_register_id,
    output logic memory_register_write_enable,
    output logic memory_read_enable,
    output logic memory_write_enable,
    output logic memory_branch_instruction,
    output logic [`WARP_SIZE-1:0] memory_branch_taken_mask,
    output logic [`WARP_SIZE-1:0] memory_branch_fallthrough_mask,
    output logic memory_branch_divergent,
    output logic [`PC_WIDTH-1:0] memory_branch_target_program_counter,
    output logic [`PC_WIDTH-1:0] memory_branch_fallthrough_program_counter,
    output logic [`PC_WIDTH-1:0] memory_branch_reconvergence_program_counter,
    output logic memory_branch_reconvergence_valid,
    output logic memory_exit_instruction
);
    logic [`LANE_WIDTH-1:0] alu_result [0:`WARP_SIZE-1];
    logic [`LANE_WIDTH-1:0] address_result [0:`WARP_SIZE-1];
    logic [`WARP_SIZE-1:0] branch_taken_mask_comb;
    logic [`WARP_SIZE-1:0] branch_fallthrough_mask_comb;
    logic branch_divergent_comb;

    logic [`PC_WIDTH-1:0] ipdom_program_counter;
    logic ipdom_valid;

    vector_alu u_vector_alu (
        .operand_a(source_register_1_data),
        .operand_b(source_register_2_data),
        .immediate_operand(execute_immediate_value),
        .use_immediate_operand(execute_uses_immediate_operand),
        .alu_operation(execute_alu_operation),
        .active_lane_mask(execute_active_lane_mask),
        .result(alu_result)
    );

    ipdom_table u_ipdom_table (
        .branch_program_counter(execute_program_counter),
        .reconvergence_program_counter(ipdom_program_counter),
        .reconvergence_valid(ipdom_valid)
    );

    genvar address_lane;
    generate
        for (address_lane = 0; address_lane < `WARP_SIZE; address_lane++) begin : GEN_ADDRESS
            assign address_result[address_lane] =
                source_register_1_data[address_lane] + execute_immediate_value;
        end
    endgenerate

    always_comb begin
        branch_taken_mask_comb = '0;
        branch_fallthrough_mask_comb = '0;

        for (int lane = 0; lane < `WARP_SIZE; lane++) begin
            if (execute_active_lane_mask[lane] && execute_instruction_valid && execute_branch_instruction) begin
                if (execute_branch_not_equal) begin
                    branch_taken_mask_comb[lane] =
                        (source_register_1_data[lane] != source_register_2_data[lane]);
                end else begin
                    branch_taken_mask_comb[lane] =
                        (source_register_1_data[lane] == source_register_2_data[lane]);
                end

                branch_fallthrough_mask_comb[lane] = ~branch_taken_mask_comb[lane];
            end
        end

        branch_divergent_comb =
            (branch_taken_mask_comb != '0) &&
            (branch_fallthrough_mask_comb != '0);
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            memory_instruction_valid <= 1'b0;
            memory_warp_id <= '0;
            memory_program_counter <= '0;
            memory_active_lane_mask <= '0;
            memory_destination_register_id <= `REG_ZERO;
            memory_register_write_enable <= 1'b0;
            memory_read_enable <= 1'b0;
            memory_write_enable <= 1'b0;
            memory_branch_instruction <= 1'b0;
            memory_branch_taken_mask <= '0;
            memory_branch_fallthrough_mask <= '0;
            memory_branch_divergent <= 1'b0;
            memory_branch_target_program_counter <= '0;
            memory_branch_fallthrough_program_counter <= '0;
            memory_branch_reconvergence_program_counter <= '0;
            memory_branch_reconvergence_valid <= 1'b0;
            memory_exit_instruction <= 1'b0;
            for (int lane = 0; lane < `WARP_SIZE; lane++) begin
                memory_alu_result[lane] <= '0;
                memory_address[lane] <= '0;
                memory_store_data[lane] <= '0;
            end
        end else begin
            memory_instruction_valid <= execute_instruction_valid;
            memory_warp_id <= execute_warp_id;
            memory_program_counter <= execute_program_counter;
            memory_active_lane_mask <= execute_active_lane_mask;
            memory_destination_register_id <= execute_destination_register_id;
            memory_register_write_enable <= execute_register_write_enable;
            memory_read_enable <= execute_memory_read_enable;
            memory_write_enable <= execute_memory_write_enable;
            memory_branch_instruction <= execute_branch_instruction;
            memory_branch_taken_mask <= branch_taken_mask_comb;
            memory_branch_fallthrough_mask <= branch_fallthrough_mask_comb;
            memory_branch_divergent <= branch_divergent_comb;
            memory_branch_target_program_counter <=
                execute_program_counter + execute_immediate_value[`PC_WIDTH-1:0];
            memory_branch_fallthrough_program_counter <= execute_program_counter + 16'd4;
            memory_branch_reconvergence_program_counter <= ipdom_program_counter;
            memory_branch_reconvergence_valid <= execute_branch_instruction && ipdom_valid;
            memory_exit_instruction <= execute_exit_instruction;

            for (int lane = 0; lane < `WARP_SIZE; lane++) begin
                memory_alu_result[lane] <= alu_result[lane];
                memory_address[lane] <= address_result[lane];
                memory_store_data[lane] <= source_register_2_data[lane];
            end
        end
    end
endmodule
