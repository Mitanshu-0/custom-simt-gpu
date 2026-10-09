// Per-warp SIMT control-flow stack.
// Each divergent branch pushes two entries:
//   1) alternate-path entry: restore the fall-through PC/mask at the IPDOM
//   2) barrier entry: restore the full pre-branch mask at the IPDOM
// This permits nested divergence because newer entries sit above older entries.

`include "../../cu_defs.svh"

module simt_stack (
    input  logic clk,
    input  logic rst,

    input  logic push_divergence,
    input  logic [`WARP_ID_WIDTH-1:0] push_warp_id,
    input  logic [`PC_WIDTH-1:0] push_fallthrough_pc,
    input  logic [`WARP_SIZE-1:0] push_fallthrough_mask,
    input  logic [`PC_WIDTH-1:0] push_reconvergence_pc,
    input  logic [`WARP_SIZE-1:0] push_full_mask,

    input  logic pop_entry,
    input  logic [`WARP_ID_WIDTH-1:0] pop_warp_id,

    output logic top_valid,
    output logic [`PC_WIDTH-1:0] top_target_pc,
    output logic [`WARP_SIZE-1:0] top_active_mask,
    output logic [`PC_WIDTH-1:0] top_reconvergence_pc,
    output logic [`SIMT_STACK_PTR_WIDTH-1:0] depth [0:`NUM_WARPS-1]
);

    logic [`PC_WIDTH-1:0] target_pc_stack [0:`NUM_WARPS-1][0:`SIMT_STACK_DEPTH-1];
    logic [`WARP_SIZE-1:0] active_mask_stack [0:`NUM_WARPS-1][0:`SIMT_STACK_DEPTH-1];
    logic [`PC_WIDTH-1:0] reconvergence_pc_stack [0:`NUM_WARPS-1][0:`SIMT_STACK_DEPTH-1];
    logic barrier_stack [0:`NUM_WARPS-1][0:`SIMT_STACK_DEPTH-1];

    always_comb begin
        top_valid = 1'b0;
        top_target_pc = '0;
        top_active_mask = '0;
        top_reconvergence_pc = '0;

        if (depth[pop_warp_id] != 0) begin
            top_valid = 1'b1;
            top_target_pc = target_pc_stack[pop_warp_id][depth[pop_warp_id]-1'b1];
            top_active_mask = active_mask_stack[pop_warp_id][depth[pop_warp_id]-1'b1];
            top_reconvergence_pc = reconvergence_pc_stack[pop_warp_id][depth[pop_warp_id]-1'b1];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int warp = 0; warp < `NUM_WARPS; warp++) begin
                depth[warp] <= '0;
                for (int entry = 0; entry < `SIMT_STACK_DEPTH; entry++) begin
                    target_pc_stack[warp][entry] <= '0;
                    active_mask_stack[warp][entry] <= '0;
                    reconvergence_pc_stack[warp][entry] <= '0;
                    barrier_stack[warp][entry] <= 1'b0;
                end
            end
        end else begin
            // The design never intentionally issues a POP and PUSH for the same warp
            // in the same cycle. PUSH is therefore handled independently per warp.
            if (pop_entry && (depth[pop_warp_id] != 0)) begin
                depth[pop_warp_id] <= depth[pop_warp_id] - 1'b1;
            end

            if (push_divergence) begin
                if (depth[push_warp_id] <= (`SIMT_STACK_DEPTH-2)) begin
                    // Lower entry: barrier. It restores the original mask at the IPDOM.
                    target_pc_stack[push_warp_id][depth[push_warp_id]] <= push_reconvergence_pc;
                    active_mask_stack[push_warp_id][depth[push_warp_id]] <= push_full_mask;
                    reconvergence_pc_stack[push_warp_id][depth[push_warp_id]] <= push_reconvergence_pc;
                    barrier_stack[push_warp_id][depth[push_warp_id]] <= 1'b1;

                    // Upper entry: alternate path. It is popped first when the
                    // taken path reaches the IPDOM.
                    target_pc_stack[push_warp_id][depth[push_warp_id]+1'b1] <=
                        push_fallthrough_pc;
                    active_mask_stack[push_warp_id][depth[push_warp_id]+1'b1] <= push_fallthrough_mask;
                    reconvergence_pc_stack[push_warp_id][depth[push_warp_id]+1'b1] <= push_reconvergence_pc;
                    barrier_stack[push_warp_id][depth[push_warp_id]+1'b1] <= 1'b0;

                    depth[push_warp_id] <= depth[push_warp_id] + 2'd2;
                end
`ifndef SYNTHESIS
                else begin
                    $error("SIMT stack overflow: warp %0d", push_warp_id);
                end
`endif
            end
        end
    end
endmodule
