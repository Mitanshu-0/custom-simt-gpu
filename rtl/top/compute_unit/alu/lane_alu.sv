// Single-lane ALU.

`include "../../cu_defs.svh"

module lane_alu #(
    parameter int LANE_WIDTH_P = `LANE_WIDTH
) (
    input  logic [LANE_WIDTH_P-1:0] operand_a,
    input  logic [LANE_WIDTH_P-1:0] operand_b,
    input  logic [LANE_WIDTH_P-1:0] immediate_operand,
    input  logic                    use_immediate_operand,
    input  logic [5:0]              alu_operation,
    output logic [LANE_WIDTH_P-1:0] result
);
    logic [LANE_WIDTH_P-1:0] second_operand;

    always_comb begin
        second_operand = use_immediate_operand ? immediate_operand : operand_b;
        unique case (alu_operation)
            `FUNC_ADD: result = operand_a + second_operand;
            `FUNC_SUB: result = operand_a - second_operand;
            `FUNC_AND: result = operand_a & second_operand;
            `FUNC_OR : result = operand_a | second_operand;
            `FUNC_XOR: result = operand_a ^ second_operand;
            `FUNC_SLT: result = ($signed(operand_a) < $signed(second_operand)) ?
                               {{(LANE_WIDTH_P-1){1'b0}},1'b1} : '0;
            default : result = '0;
        endcase
    end
endmodule
