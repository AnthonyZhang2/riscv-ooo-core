`timescale 1ns/1ps


module reservation_tb
import rv32i_types::*;
();
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
    end
    logic clk;

    always #5 clk = ~clk;
    logic rst;

    // Instantiate types imported from rv32i_types
    // RS_Entry and cdb_t should be defined in that package.
    RS_Entry new_rs_entry;
    cdb_t    data_bus;
    
    // Control signal to indicate execution completion
    logic complete;
    
    // Outputs from the reservation module
    logic full;
    logic exec_valid;
    logic [6:0] exec_opcode;
    logic [2:0] funct3;
    logic [31:0] exec_operand1, exec_operand2;
    logic [4:0] exec_dest;

    reservation #(
        .NUM_STATIONS(8)
    ) dut (
        .clk            (clk),
        .rst            (rst),
        .new_rs_entry   (new_rs_entry),
        .complete       (complete),
        .data_bus       (data_bus),
        .full           (full),
        .exec_valid     (exec_valid),
        .exec_funct3    (funct3),
        .exec_opcode    (exec_opcode),
        .exec_operand1  (exec_operand1),
        .exec_operand2  (exec_operand2),
        .exec_dest      (exec_dest)
    );

    initial begin
        $display("\nStarting Testbench\n");
        complete = 1'b0;

        new_rs_entry.busy   = 1'b1;      // Enable the new entry
        new_rs_entry.opcode = 7'h13;     // Opcode for 13      
        new_rs_entry.funct3 = 3'd0;
        new_rs_entry.Vj     = 32'd10;    // Initial register val of 10
        new_rs_entry.Vk     = 32'd1;     // 1 intermediate val
        new_rs_entry.Qj     = 5'd1;      // dependency, ready to exec
        new_rs_entry.Qk     = 5'd0;      // No dependency, ready to exec
        new_rs_entry.dest   = 5'd10;      
        new_rs_entry.rob_address   = 5'd0;  

        data_bus.valid = 1'd0;
        data_bus.exec_result = 32'd0;
        data_bus.rob_idx = 5'd0;
        data_bus.branch = 1'd0;

        clk = 1'b0;
        rst = 1'b1;
        #20
        rst = 1'b0;
        @(posedge clk);  
        
        //Simulated addi a0, a0, #1
        new_rs_entry.busy   = 1'b1;      // Enable the new entry
        new_rs_entry.opcode = 7'h13;     // Opcode for 13      
        new_rs_entry.Vj     = 32'd0;    // Initial register val of 10
        new_rs_entry.Vk     = 32'd1;     // 1 intermediate val
        new_rs_entry.Qj     = 5'd01;      // dependency, ready to exec
        new_rs_entry.Qk     = 5'd0;      // No dependency, ready to exec
        new_rs_entry.dest   = 5'd10;      
        new_rs_entry.rob_address   = 5'd0;  

        @(posedge clk);    

        for(integer i = 1; i < 7; i++) begin
            //Simulated addi a0, a0, #1
            new_rs_entry.busy   = 1'b1;      // Enable the new entry
            new_rs_entry.opcode = 7'h13;     // Opcode for 13      
            new_rs_entry.funct3 = 3'(i);
            new_rs_entry.Vj     = 32'(i);    // Initial register val of 10
            new_rs_entry.Vk     = 32'd1;     // 1 intermediate val
            new_rs_entry.Qj     = 5'(i);      //  dependency, not ready to exec
            new_rs_entry.Qk     = 5'd0;      // No dependency, ready to exec
            new_rs_entry.dest   = 5'd10;      
            new_rs_entry.rob_address   = 5'd1; //This is wrong but it doesn't matter  

            @(posedge clk);     
        end

        //This is to check whether or not we update the data properly
        new_rs_entry.busy   = 1'b1;      // Enable the new entry
        new_rs_entry.opcode = 7'h13;     // Opcode for 13      
        new_rs_entry.Vj     = 32'd8;    // Initial register val of 10
        new_rs_entry.Vk     = 32'd1;     // 1 intermediate val
        new_rs_entry.Qj     = 5'd0;      // no dependency, not ready to exec
        new_rs_entry.Qk     = 5'd0;      // No dependency, ready to exec
        new_rs_entry.dest   = 5'd10;      
        new_rs_entry.rob_address   = 5'd1; //This is wrong but it doesn't matter  

        @(posedge clk);   
        if(!full) 
            $error("ERROR, Should be full we have not executed an instruction yet");
        @(posedge clk);
        
        complete = 1'b1;
        data_bus.valid = 1'b1;
        data_bus.rob_idx = 5'd2;
        data_bus.exec_result = 32'hAAAAAAAA;

        new_rs_entry.busy   = 1'b0;      // Enable the new entry
        
        @(posedge clk);
        
        complete = 1'b0;

        
        @(posedge clk);
        if(exec_operand1 != 32'hAAAAAAAA)
            $error("ERROR, operand 1 should read AAAAAAAA. Instead read %x", exec_operand1);

        @(posedge clk);
        complete = 1'b1;
        data_bus.valid = 1'b1;
        data_bus.rob_idx = 5'd3;
        data_bus.exec_result = 32'hBBBBBBBB;



        @(posedge clk);
        
        complete = 1'b0;

        @(posedge clk);
        if(exec_operand1 != 32'hBBBBBBBB)
            $error("ERROR, operand 1 should read BBBBBBBB. Instead read %x", exec_operand1);


        $display("\n***************************************************************");
        $display("                     All Tests Complete!                         ");
        $display("***************************************************************\n");

    end

  
    initial begin
        #200 $finish(1);
    end

endmodule : reservation_tb