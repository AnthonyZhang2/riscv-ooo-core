`timescale 1ns/1ps

module fetch_tb();
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
    end
    logic clk;

    always #5 clk = ~clk;

    logic               rst;

    // logic   [31:0]      ufp_addr;     // signals from cache
    // logic   [3:0]       ufp_read;
    // logic   [3:0]       ufp_write;
    // logic   [31:0]      ufp_rdata;
    // logic   [31:0]      ufp_wdata;
    // logic               ufp_resp;

    // logic   [31:0]      dfp_addr;     // signals from cache
    // logic               dfp_read;
    // logic               dfp_write;
    // logic   [255:0]     dfp_rdata;
    // logic   [255:0]     dfp_wdata;
    // logic               dfp_resp;

    logic   [31:0]      bmem_addr;    // signals from dram
    logic               bmem_read;
    logic               bmem_write;
    logic   [63:0]      bmem_wdata;
    logic               bmem_ready;   // unused, assumed always 1
    logic   [31:0]      bmem_raddr;   // unused, only needed for multiple outstanding memory requests
    logic   [63:0]      bmem_rdata;
    logic               bmem_rvalid;
    logic   [63:0]      temp;
    logic               dequeue;
    // cacheline_adapter cacheline_test (
    //     .clk        (clk),
    //     .rst        (rst),

    //     .dfp_addr   (dfp_addr),
    //     .dfp_read   (dfp_read),
    //     .dfp_write  (dfp_write),
    //     .dfp_rdata  (dfp_rdata),
    //     .dfp_wdata  (dfp_wdata),
    //     .dfp_resp   (dfp_resp),

    //     .bmem_addr   (bmem_addr),
    //     .bmem_read   (bmem_read),
    //     .bmem_write  (bmem_write),
    //     .bmem_rdata  (bmem_rdata),
    //     .bmem_wdata  (bmem_wdata),
    //     .bmem_ready  (1'b1),
    //     .bmem_raddr  (32'b0),
    //     .bmem_rvalid (bmem_rvalid)
    // );

    // provided_cache cache_test (
    //     .clk        (clk),
    //     .rst        (rst),
        
    //     .ufp_addr   (ufp_addr),
    //     .ufp_rmask  (ufp_rmask),
    //     .ufp_wmask  (ufp_wmask),
    //     .ufp_rdata  (ufp_rdata),
    //     .ufp_wdata  (ufp_wdata),
    //     .ufp_resp   (ufp_resp),

    //     .dfp_addr   (dfp_addr),
    //     .dfp_read   (dfp_read),
    //     .dfp_write  (dfp_write),
    //     .dfp_rdata  (dfp_rdata),
    //     .dfp_wdata  (dfp_wdata),
    //     .dfp_resp   (dfp_resp)
    // );

    cpu dut(
        .clk(clk),
        .rst(rst),
        .dequeue(dequeue),

        .bmem_addr(bmem_addr), //output
        .bmem_read(bmem_read),  //output 
        .bmem_write(bmem_write), //output
        .bmem_wdata(bmem_wdata),  //output
        .bmem_ready(bmem_ready),  //input

        .bmem_raddr(bmem_raddr), //input
        .bmem_rdata(bmem_rdata), //input
        .bmem_rvalid(bmem_rvalid) //input
    );
    
    initial begin
        $display("Starting Test with Burst Write 32B");
        clk = 1'b0;
        rst = 1'b1;
        dequeue = 1'b0;
        #10 rst = 1'b0;
        bmem_raddr = 32'hAAAAA000;
        bmem_ready = 1'b0;
        @(posedge clk);
        bmem_rdata = 64'hBBBBBBBBAAAAAAAA; //goes from 63->0, right to left.
        bmem_rvalid = 1'b1;
        @(posedge clk);
        bmem_rdata = 64'hDDDDDDDDCCCCCCCC;
        @(posedge clk);
        bmem_rdata = 64'hFFFFFFFFEEEEEEEE;
        @(posedge clk);
        bmem_rdata = 64'hDEADBEEFA5A5A5A5;
        @(posedge clk);
        bmem_rvalid = 1'b0;
        bmem_rdata = 64'h0;
        $display("Begin Reading \n\n\n");
        #100
        dequeue = 1'b1;
        temp = dut.rd_data;
        $display("%t READ : data=%0h head=%0d",
                $time, temp, dut.instruction_queue.head);
        #10
        temp = dut.rd_data;
        $display("%t READ : data=%0h head=%0d",
                    $time, temp, dut.instruction_queue.head);
        #10
        temp = dut.rd_data;
        $display("%t READ : data=%0h head=%0d",
                    $time, temp, dut.instruction_queue.head);
        #10
        temp = dut.rd_data;
        $display("%t READ : data=%0h head=%0d",
                    $time, temp, dut.instruction_queue.head);
        #10
        temp = dut.rd_data;
        $display("%t READ : data=%0h head=%0d",
                    $time, temp, dut.instruction_queue.head);
        #10
        temp = dut.rd_data;
        $display("%t READ : data=%0h head=%0d",
                    $time, temp, dut.instruction_queue.head);

        #10
        temp = dut.rd_data;
        $display("%t READ : data=%0h head=%0d",
                    $time, temp, dut.instruction_queue.head);
        #10
        temp = dut.rd_data;
        $display("%t READ : data=%0h head=%0d",
                    $time, temp, dut.instruction_queue.head);
        
        dequeue = 1'b0;

        $display("\n Finished Test!\n");
    end

    always_ff @(posedge clk) begin
        if (dut.fetch_resp && !dut.full) begin
            $display("%t WRITE: data=%0h tail=%0d",
                $time, dut.write_data, dut.instruction_queue.tail);
        end
    end

    initial begin
        $display("got here");
        #500 $finish(1);
    end

endmodule : fetch_tb