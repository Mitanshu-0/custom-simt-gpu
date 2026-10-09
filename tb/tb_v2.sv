`timescale 1ns/1ps

module tb_v2;
    logic clk = 1'b0;
    logic rst = 1'b1;

    top dut (.clk(clk), .rst(rst));

    always #5 clk = ~clk;

    initial begin
        repeat (4) @(posedge clk);
        rst <= 1'b0;

        repeat (400) @(posedge clk);

        for (int warp = 0; warp < 4; warp++) begin
            if (dut.u_compute_unit.u_warp_manager.warp_state[warp] !== 2'b10)
                $fatal(1, "Warp %0d did not reach DONE; state=%b PC=%0d mask=%b",
                       warp,
                       dut.u_compute_unit.u_warp_manager.warp_state[warp],
                       dut.u_compute_unit.u_warp_manager.warp_program_counter[warp],
                       dut.u_compute_unit.u_warp_manager.warp_active_lane_mask[warp]);

            if (dut.u_compute_unit.u_warp_manager.simt_stack_depth[warp] !== 0)
                $fatal(1, "Warp %0d SIMT stack not empty: depth=%0d",
                       warp, dut.u_compute_unit.u_warp_manager.simt_stack_depth[warp]);

            for (int lane = 0; lane < 4; lane++) begin
                if (dut.u_compute_unit.u_register_file.registers[warp][lane][4] !== 32'd99)
                    $fatal(1, "Warp %0d lane %0d R4=%0d, expected 99",
                           warp, lane, dut.u_compute_unit.u_register_file.registers[warp][lane][4]);
            end
        end

        $display("PASS: V2 default divergence/reconvergence RTL test");
        $finish;
    end
endmodule
