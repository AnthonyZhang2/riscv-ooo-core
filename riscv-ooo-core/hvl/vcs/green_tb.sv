`timescale 1ns/1ps


module green_tb
import rv32i_types::*;
();
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
    end
    logic clk;

    always #5 clk = ~clk;
    logic rst;

    // Declare signals for connecting to the reorder module
    logic [4:0] dest_reg;
    instr_variants instr_type;
    logic input_valid;
    logic [63:0] order;
    cdb_t data_bus;
    logic flush;
    logic [4:0] commit_dest;
    instr_variants commit_type;
    logic [31:0] commit_result;
    logic commit_valid;
    logic branch_taken;
    logic [63:0] commit_order;
    logic full;
    logic [$clog2(32)-1:0] phys_rs1_s, phys_rs2_s;
    logic [31:0] phys_rs1_v, phys_rs2_v;
    logic [$clog2(32)-1:0] tail_out;

    // Instantiate the reorder module
    reorder reorder_buffer (
        .clk(clk),
        .rst(rst),

        //Adding Instructions
        .instr_type(instr_type), // Replace '0 with appropriate test value
        .dest_reg(dest_reg),
        .input_valid(input_valid),
        .order(order),

        //From execution unit
        .data_bus(data_bus),

        .flush(flush),

        //Outputs
        .commit_dest(commit_dest),
        .commit_type(commit_type),
        .commit_result(commit_result),
        .commit_valid(commit_valid),
        .branch_taken(branch_taken),
        .commit_order(commit_order),

        .full(full),
        .phys_rs1_s(phys_rs1_s),
        .phys_rs2_s(phys_rs2_s),
        .phys_rs1_v(phys_rs1_v),
        .phys_rs2_v(phys_rs2_v),
        .tail_out(tail_out)
    );

    // Declare signals for connecting to the CDB module
    logic [31:0] alu_out, mul_out, div_out, mem_out;
    logic alu_valid, mul_valid, div_valid, mem_valid;
    logic [$clog2(32)-1:0] alu_rob_idx, mul_rob_idx, div_rob_idx, mem_rob_idx;
    logic branch;
    logic stall_div, stall_mul;
    logic alu_complete, mul_complete, div_complete, mem_complete;

    // Instantiate the CDB module
    cdb cdb_inst (
        .clk(clk),
        .rst(rst),

        .alu_out(alu_out),
        .alu_valid(alu_valid),
        .alu_rob_idx(alu_rob_idx),

        .mul_out(mul_out),
        .mul_valid(mul_valid),
        .mul_rob_idx(mul_rob_idx),

        .div_out(div_out),
        .div_valid(div_valid),
        .div_rob_idx(div_rob_idx),

        .mem_out(mem_out),
        .mem_valid(mem_valid),
        .mem_rob_idx(mem_rob_idx),

        .branch(branch),

        .cdb_out(data_bus),

        .stall_div(stall_div),
        .stall_mul(stall_mul),

        .alu_complete(alu_complete),
        .mul_complete(mul_complete),
        .div_complete(div_complete),
        .mem_complete(mem_complete)
    );

    logic regf_we;
    logic [31:0] rd_v;
    logic [4:0] rd_s;

    logic [31:0] mem_addr;
    logic mem_write;
    logic [63:0] commit_out;

    commit commit_module (
        .clk(clk),
        .rst(rst),

        .commit_dest(commit_dest),
        .commit_type(commit_type),
        .commit_result(commit_result),
        .commit_valid(commit_valid),
        .branch_taken(branch_taken),
        .commit_order(commit_order),

        .rd_v(rd_v),
        .regf_we(regf_we),
        .rd_s(rd_s),

        .mem_addr(mem_addr),
        .mem_write(mem_write),
        .commit_out(commit_out)
    );

    logic   [4:0]   rs1_s, rs2_s;
    logic   [31:0]  rs1_v, rs2_v;

    regfile registers (
        .clk(clk),
        .rst(rst),

        .regf_we(regf_we),
        .rd_v(rd_v),
        .rd_s(rd_s),
        .rs1_s(rs1_s),
        .rs2_s(rs2_s),
        .rs1_v(rs1_v),
        .rs2_v(rs2_v)
    );


    initial begin
        $display("\n\n");
        clk = 1'b0;
        rst = 1'b1;

        //Instantiate CDB
        alu_out = 32'd0;
        alu_valid = 1'b0;
        alu_rob_idx = 5'd0;
        mul_out = 32'd0;
        mul_valid = 1'b0;
        mul_rob_idx = 5'd0;
        div_out = 32'd0;
        div_valid = 1'b0;
        div_rob_idx = 5'd0;
        mem_out = 32'd0;
        mem_valid = 1'b0;
        mem_rob_idx = 5'd0;
        branch = 1'b0;
        
        rs1_s = 5'd3;

        #10 rst = 1'b0;

        //Now Load into Reorder
        input_valid = 1'b1;
        instr_type = r_type;
        dest_reg = 5'd3; //load into x2
        for(integer i = 0; i < 12; i++) begin
            order = i;
            @(posedge clk);
        end
        input_valid = 1'b0;

        @(posedge clk);
        @(posedge clk);
        alu_out = 32'hAAAAAAAA;
        alu_valid = 1'b1;
        alu_rob_idx = 5'd4;

        @(posedge clk);
        alu_valid = 1'b0; // Should not commit

        @(posedge clk);
        alu_valid = 1'b1;
        alu_rob_idx = 5'd0;
        alu_out = 32'hBBBBBBBB;

        @(posedge clk);
        alu_valid = 1'b0;

        @(posedge clk);
        alu_valid = 1'b1;
        alu_rob_idx = 5'd1;
        alu_out = 32'hCCCCCCCC;

        @(posedge clk);
        alu_valid = 1'b1;
        alu_rob_idx = 5'd2;
        alu_out = 32'hDDDDDDDD;

        @(posedge clk);
        alu_valid = 1'b1;
        alu_rob_idx = 5'd3;
        alu_out = 32'hEEEEEEEE;

        @(posedge clk);
        alu_valid = 1'b0;


        $display("\n***************************************************************");
        $display("                          Test Completed                         ");
        $display("***************************************************************\n");

        $display("\n***************************************************************");
        $display("                     All Tests Complete!                         ");
        $display("***************************************************************\n\n\n\n");

    end

  
    initial begin
        #500 $finish(1);
    end

endmodule : green_tb