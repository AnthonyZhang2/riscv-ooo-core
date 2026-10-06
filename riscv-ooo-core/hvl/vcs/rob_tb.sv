`timescale 1ns/1ps


module rob_tb
import rv32i_types::*;
();
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
    end
    logic clk;

    always #5 clk = ~clk;
    logic rst;

    // Control Signals
    logic input_valid;
    logic flush;
    logic [63:0] order;
    instr_variants instr_type;
    logic [4:0] dest_reg;

    // Execution unit signals
    cdb_t data_bus;

    // PRF select signals
    logic [4:0] phys_rs1_s, phys_rs2_s;

    // Outputs from reorder
    logic [4:0] commit_dest;
    logic [31:0] commit_result;
    instr_variants commit_type;
    logic commit_valid;
    logic branch_taken;
    logic [31:0] phys_rs1_v, phys_rs2_v;
    logic [4:0] tail;
    logic full;

    // Instantiate the DUT (reorder module)
    reorder dut (
        .clk(clk),
        .rst(rst),
        .instr_type(instr_type),
        .dest_reg(dest_reg),
        .input_valid(input_valid),
        .data_bus(data_bus),
        .order(order),
        .flush(flush),
        .commit_dest(commit_dest),
        .commit_result(commit_result),
        .commit_valid(commit_valid),
        .branch_taken(branch_taken),
        .commit_type(commit_type),
        .phys_rs1_s(phys_rs1_s),
        .phys_rs2_s(phys_rs2_s),
        .phys_rs1_v(phys_rs1_v),
        .phys_rs2_v(phys_rs2_v),
        .full(full),
        .tail_out(tail)
    );

    initial begin
        $display("\n\n");
        $display("Starting Test with PRF");
        $display("Simple PRF Write and Read");
        clk = 1'b0;
        rst = 1'b1;

        input_valid = 1'b0;
        flush = 1'b0;
        order = 1'b0;
        instr_type = instr_variants'(0);
        dest_reg = 5'd0;

        data_bus.valid = 1'b0;
        data_bus.exec_result = 32'd0;
        data_bus.rob_idx = 5'd0;
        data_bus.branch = 1'd0;

        phys_rs1_s = '0;
        phys_rs2_s = '0;

        #10
        rst = 1'b0;

        for(integer i = 0; i < 5; i++) begin
            input_valid = 1'b1;
            order = i;
            
            @(posedge clk);
        end
        
        input_valid = 1'b0;

        //Finished third instruction

        data_bus.valid = 1'd1;
        data_bus.exec_result = 32'hCCCCCCCC;
        data_bus.rob_idx = 5'd2;
        data_bus.branch = 1'd0;

        @(posedge clk);

        //data_bus.valid = 1'd0;
        // Finished fourth instruction
        data_bus.valid = 1'd1;
        data_bus.exec_result = 32'hDDDDDDDD;
        data_bus.rob_idx = 5'd3;
        data_bus.branch = 1'd0;
        @(posedge clk);


        //Now finished first instruciton, can commit now
        data_bus.valid = 1'd1;
        data_bus.exec_result = 32'hAAAAAAAA;
        data_bus.rob_idx = 5'd0;
        data_bus.branch = 1'd0;
        @(posedge clk);

        @(posedge clk);

        //Now finished second instruction, can commit the rest
        data_bus.valid = 1'd1;
        data_bus.exec_result = 32'hBBBBBBBB;
        data_bus.rob_idx = 5'd1;
        data_bus.branch = 1'd0;

        @(posedge clk);

        data_bus.valid = 1'd0;

        $display("Reg 1 read %x", phys_rs1_v);
        $display("Reg 2 read %x", phys_rs2_v);
        

        $display("\n************************** *************************************");
        $display("                          Test Completed                         ");
        $display("***************************************************************\n");

        $display("\n***************************************************************");
        $display("                     All Tests Complete!                         ");
        $display("***************************************************************\n\n\n\n");

    end

  
    initial begin
        #200 $finish(1);
    end

endmodule : rob_tb