# Outer divergence: R1 != 1 -> taken path (lanes 0,2,3), lane 1 is fall-through.
# Inner divergence on the outer-taken path: R1 == 0 -> lane 0 taken, lanes 2/3 fall through.
# BEQ R0,R0 is an unconditional branch used to skip the outer taken path from the else block.
start:
    ADDI R2, R0, 1
    BNE  R1, R2, outer_taken
    ADDI R3, R0, 99
    ADDI R4, R0, 7
    ADDI R5, R0, 8
    BEQ  R0, R0, join
outer_taken:
    ADDI R3, R0, 0
    BEQ  R1, R3, join
    ADDI R6, R0, 11
    ADDI R6, R0, 12
    ADDI R7, R0, 13
join:
    ADDI R8, R0, 14
    EXIT
