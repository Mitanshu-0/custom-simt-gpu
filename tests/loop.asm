# Uniform loop: R3 counts 0..2 and the BNE branches back to the loop body.
start:
    ADDI R2, R0, 3
    ADDI R3, R0, 0
loop_body:
    ADDI R3, R3, 1
    BNE  R3, R2, loop_body
loop_exit:
    ADDI R4, R0, 7
    EXIT
