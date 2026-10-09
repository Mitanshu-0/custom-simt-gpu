// Parallel vector ALU composed of one lane ALU per active lane.

`include "../../cu_defs.svh"

module vector_alu #(
    parameter int WARP_SIZE_P  = `WARP_SIZE,
    parameter int LANE_WIDTH_P = `LANE_WIDTH
) (
    input  logic [LANE_WIDTH_P-1:0] operand_a [0:WARP_SIZE_P-1],
    input  logic [LANE_WIDTH_P-1:0] operand_b [0:WARP_SIZE_P-1],
    input  logic [LANE_WIDTH_P-1:0] immediate_operand,
    input  logic                    use_immediate_operand,
    input  logic [5:0]              alu_operation,
    input  logic [WARP_SIZE_P-1:0]  active_lane_mask,
    output logic [LANE_WIDTH_P-1:0] result [0:WARP_SIZE_P-1]
);
    genvar lane;
    generate
        for (lane = 0; lane < WARP_SIZE_P; lane++) begin : GEN_LANE_ALU
            logic [LANE_WIDTH_P-1:0] lane_result;
            lane_alu #(.LANE_WIDTH_P(LANE_WIDTH_P)) u_lane_alu (
                .operand_a(operand_a[lane]),
                .operand_b(operand_b[lane]),
                .immediate_operand(immediate_operand),
                .use_immediate_operand(use_immediate_operand),
                .alu_operation(alu_operation),
                .result(lane_result)
            );
            assign result[lane] = active_lane_mask[lane] ? lane_result : '0;
        end
    endgenerate
endmodule
