# Per-lane divergence: R1 is lane TID, R2=1.
# Lane 1 takes the branch; lanes 0/2/3 execute the fall-through path.
start:
    ADDI R2, R0, 1
    BEQ  R1, R2, taken
    ADDI R3, R0, 20
    ADDI R3, R3, 1
taken:
    ADDI R4, R0, 99
    EXIT
