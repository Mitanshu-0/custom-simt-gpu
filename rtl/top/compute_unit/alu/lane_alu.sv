// Single 32-bit lane ALU

`include "../../cu_defs.svh"

module lane_alu #(
    parameter int `LANE_WIDTH = `LANE_WIDTH              // LANE_WIDTH = 32 → 32 bits/lane
) (
    input  logic [`LANE_WIDTH-1:0] operand_a, // LANE_WIDTH = 32 → [31:0], operand A
    input  logic [`LANE_WIDTH-1:0] operand_b, // LANE_WIDTH = 32 → [31:0], operand B
    input  logic [`LANE_WIDTH-1:0] immediate_operand, // LANE_WIDTH = 32 → [31:0], 32-bit immediate
    input  logic                  use_immediate_operand, // Select immediate_operand instead of operand_b
    input  logic [5:0]            alu_operation, // 6-bit ALU operation
    output logic [`LANE_WIDTH-1:0] result // LANE_WIDTH = 32 → [31:0], lane result
);
    logic [`LANE_WIDTH-1:0] second_operand; // LANE_WIDTH = 32 → [31:0], selected second operand

    always_comb begin
        second_operand = use_immediate_operand ? immediate_operand : operand_b; // Select immediate or register operand
        unique case (alu_operation)
            `FUNC_ADD: result = operand_a + second_operand; // Add operands
            `FUNC_SUB: result = operand_a - second_operand; // Subtract second operand from operand A
            `FUNC_AND: result = operand_a & second_operand; // Bitwise AND
            `FUNC_OR : result = operand_a | second_operand; // Bitwise OR
            `FUNC_XOR: result = operand_a ^ second_operand; // Bitwise XOR
            `FUNC_SLT: result = ($signed(operand_a) < $signed(second_operand)) ? {{(`LANE_WIDTH-1){1'b0}},1'b1} : '0;
            // LANE_WIDTH = 32 → {{31{1'b0}},1'b1} = 32'b1, signed less-than result
            default : result = '0; // Result is zero for unsupported ALU operation
        endcase
    end
endmodule
