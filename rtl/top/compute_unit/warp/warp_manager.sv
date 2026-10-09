// Warp scheduling, branch divergence, SIMT reconvergence, and warp state control.

`include "../../cu_defs.svh"

module warp_manager (
    input  logic clk,
    input  logic rst,

    input  logic stall_requested,
    input  logic [`WARP_ID_WIDTH-1:0] stall_warp_id,
    input  logic [`PC_WIDTH-1:0] stall_program_counter,
    input  logic stall_is_branch,
    input  logic stall_is_exit,

    input  logic [`NUM_WARPS-1:0] dependency_resolved_for_warp,

    input  logic branch_commit,
    input  logic [`WARP_ID_WIDTH-1:0] branch_warp_id,
    input  logic [`WARP_SIZE-1:0] branch_taken_mask,
    input  logic [`WARP_SIZE-1:0] branch_fallthrough_mask,
    input  logic branch_divergent,
    input  logic [`PC_WIDTH-1:0] branch_target_program_counter,
    input  logic [`PC_WIDTH-1:0] branch_fallthrough_program_counter,
    input  logic [`PC_WIDTH-1:0] branch_reconvergence_program_counter,
    input  logic branch_reconvergence_valid,
    input logic [`WARP_SIZE-1:0] branch_active_lane_mask,

    input  logic exit_commit,
    input  logic [`WARP_ID_WIDTH-1:0] exit_warp_id,

    output logic instruction_issue_valid,
    output logic [`WARP_ID_WIDTH-1:0] selected_warp_id,
    output logic [`PC_WIDTH-1:0] selected_warp_program_counter,
    output logic [`WARP_SIZE-1:0] selected_warp_active_lane_mask,
    output logic [`WARP_STATE_WIDTH-1:0] warp_state [0:`NUM_WARPS-1],
    output logic [`PC_WIDTH-1:0] warp_program_counter [0:`NUM_WARPS-1],
    output logic [`WARP_SIZE-1:0] warp_active_lane_mask [0:`NUM_WARPS-1]
);

    localparam logic [1:0] STALL_REASON_DEPENDENCY = 2'd0;
    localparam logic [1:0] STALL_REASON_BRANCH = 2'd1;
    localparam logic [1:0] STALL_REASON_EXIT = 2'd2;

    logic [1:0] stall_reason [0:`NUM_WARPS-1];
    logic [`WARP_ID_WIDTH-1:0] round_robin_pointer;
    logic found;

    logic simt_top_valid;
    logic [`PC_WIDTH-1:0] simt_top_target_pc;
    logic [`WARP_SIZE-1:0] simt_top_active_mask;
    logic [`PC_WIDTH-1:0] simt_top_reconvergence_pc;
    logic [`SIMT_STACK_PTR_WIDTH-1:0] simt_stack_depth [0:`NUM_WARPS-1];
    logic simt_pop;

    // The currently selected warp is the only warp for which a reconvergence
    // token can be consumed in this cycle.
    assign simt_pop = found &&
                      (warp_state[selected_warp_id] == `WARP_READY) &&
                      simt_top_valid &&
                      (warp_program_counter[selected_warp_id] == simt_top_reconvergence_pc);

    always_comb begin
        int candidate;
        found = 1'b0;
        selected_warp_id = round_robin_pointer;

        for (int offset = 0; offset < `NUM_WARPS; offset++) begin
            candidate = round_robin_pointer + offset;
            if (candidate >= `NUM_WARPS)
                candidate = candidate - `NUM_WARPS;
            if (!found && (warp_state[candidate] == `WARP_READY)) begin
                found = 1'b1;
                selected_warp_id = candidate[`WARP_ID_WIDTH-1:0];
            end
        end

        selected_warp_program_counter = warp_program_counter[selected_warp_id];
        selected_warp_active_lane_mask = warp_active_lane_mask[selected_warp_id];

        // Do not issue the reconvergence instruction itself. The stack event
        // changes PC/mask first; the next cycle fetches the restored path.
        instruction_issue_valid = found &&
                                  !(stall_requested && (stall_warp_id == selected_warp_id)) &&
                                  !simt_pop;
    end

    simt_stack u_simt_stack (
        .clk(clk),
        .rst(rst),
        .push_divergence(branch_commit && branch_divergent && branch_reconvergence_valid),
        .push_warp_id(branch_warp_id),
        .push_fallthrough_pc(branch_fallthrough_program_counter),
        .push_fallthrough_mask(branch_fallthrough_mask),
        .push_reconvergence_pc(branch_reconvergence_program_counter),
        .push_full_mask(branch_active_lane_mask),
        .pop_entry(simt_pop),
        .pop_warp_id(selected_warp_id),
        .top_valid(simt_top_valid),
        .top_target_pc(simt_top_target_pc),
        .top_active_mask(simt_top_active_mask),
        .top_reconvergence_pc(simt_top_reconvergence_pc),
        .depth(simt_stack_depth)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            round_robin_pointer <= '0;
            for (int warp = 0; warp < `NUM_WARPS; warp++) begin
                warp_program_counter[warp] <= '0;
                warp_active_lane_mask[warp] <= `FULL_MASK;
                warp_state[warp] <= `WARP_READY;
                stall_reason[warp] <= STALL_REASON_DEPENDENCY;
            end
        end else begin
            // Normal issue advances by one instruction. A branch stall or
            // reconvergence event overrides this default update below.
            if (instruction_issue_valid) begin
                warp_program_counter[selected_warp_id] <=
                    warp_program_counter[selected_warp_id] + 16'd4;

                if (selected_warp_id == `NUM_WARPS-1)
                    round_robin_pointer <= '0;
                else
                    round_robin_pointer <= selected_warp_id + 1'b1;
            end

            // A decoded dependency/branch/EXIT prevents another instruction
            // from the same warp from entering the fetch pipe.
            if (stall_requested) begin
                warp_state[stall_warp_id] <= `WARP_STALL;
                if (stall_is_exit)
                    stall_reason[stall_warp_id] <= STALL_REASON_EXIT;
                else if (stall_is_branch)
                    stall_reason[stall_warp_id] <= STALL_REASON_BRANCH;
                else
                    stall_reason[stall_warp_id] <= STALL_REASON_DEPENDENCY;

                if (stall_is_branch)
                    warp_program_counter[stall_warp_id] <= stall_program_counter + 16'd4;
                else
                    warp_program_counter[stall_warp_id] <= stall_program_counter;
            end

            for (int warp = 0; warp < `NUM_WARPS; warp++) begin
                if ((warp_state[warp] == `WARP_STALL) &&
                    (stall_reason[warp] == STALL_REASON_DEPENDENCY) &&
                    dependency_resolved_for_warp[warp]) begin
                    warp_state[warp] <= `WARP_READY;
                    stall_reason[warp] <= STALL_REASON_DEPENDENCY;
                end
            end

            // Reconvergence has priority over the ordinary +4 PC update.
            if (simt_pop) begin
                warp_program_counter[selected_warp_id] <= simt_top_target_pc;
                warp_active_lane_mask[selected_warp_id] <= simt_top_active_mask;
                warp_state[selected_warp_id] <= `WARP_READY;
                stall_reason[selected_warp_id] <= STALL_REASON_DEPENDENCY;
            end

            if (branch_commit) begin
                if (branch_divergent) begin
                    // The taken path executes first. The fall-through path and
                    // the IPDOM are saved by the SIMT stack.
                    if (branch_reconvergence_valid) begin
                        warp_program_counter[branch_warp_id] <= branch_target_program_counter;
                        warp_active_lane_mask[branch_warp_id] <= branch_taken_mask;
                    end else begin
`ifndef SYNTHESIS
                        $error("Missing IPDOM metadata for divergent branch in warp %0d at PC %0d",
                               branch_warp_id, branch_fallthrough_program_counter - 16'd4);
`endif
                        warp_program_counter[branch_warp_id] <= branch_fallthrough_program_counter;
                        warp_active_lane_mask[branch_warp_id] <= branch_fallthrough_mask;
                    end
                end else if (branch_taken_mask != '0) begin
                    // Uniform taken branch.
                    warp_program_counter[branch_warp_id] <= branch_target_program_counter;
                    warp_active_lane_mask[branch_warp_id] <= branch_taken_mask;
                end else begin
                    // Uniform not-taken branch.
                    warp_program_counter[branch_warp_id] <= branch_fallthrough_program_counter;
                    warp_active_lane_mask[branch_warp_id] <= branch_fallthrough_mask;
                end

                warp_state[branch_warp_id] <= `WARP_READY;
                stall_reason[branch_warp_id] <= STALL_REASON_DEPENDENCY;
            end

            if (exit_commit) begin
                warp_state[exit_warp_id] <= `WARP_DONE;
                stall_reason[exit_warp_id] <= STALL_REASON_DEPENDENCY;
            end
        end
    end
endmodule
