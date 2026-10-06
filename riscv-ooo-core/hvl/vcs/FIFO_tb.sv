`timescale 1ns/1ps

module FIFO_tb();

   initial begin
      $fsdbDumpfile("dump.fsdb");
      $fsdbDumpvars(0, "+all");
   end

   localparam DATA_WIDTH = 32;
   localparam DEPTH      = 8;
   localparam CLK_PERIOD = 10;  // 100 MHz

   logic                  clk;
   logic                  rst;

   logic                  enqueue;
   logic [DATA_WIDTH-1:0] wr_data;

   logic                  dequeue;
   logic [DATA_WIDTH-1:0] rd_data;

   logic                  full;
   logic                  empty;

   FIFO #(
       .DATA_WIDTH(DATA_WIDTH),
       .DEPTH     (DEPTH)
   ) dut (
       .clk      (clk),
       .rst      (rst),
       .enqueue  (enqueue),
       .wr_data  (wr_data),
       .dequeue  (dequeue),
       .rd_data  (rd_data),
       .full     (full),
       .empty    (empty)
   );

   initial begin
      clk = 1'b0;
      forever #(CLK_PERIOD/2) clk = ~clk;
   end

   initial begin
      rst   = 1'b0;
      enqueue   = 1'b0;
      wr_data = '0;
      dequeue   = 1'b0;

      $display("[TB] Applying reset...");
      repeat (2) @(posedge clk); 
      rst = 1'b1;
      @(posedge clk);
      rst = 1'b0;
      // basic write/read
      $display("[TB] Basic write/read test");
      // write 4 items
      repeat (4) begin
         @(posedge clk);
         enqueue   = 1'b1;
         wr_data = wr_data + 1'b1;
      end
      // stop writing
      @(posedge clk);
      enqueue = 1'b0;

      // read back 4 items
      repeat (4) begin
         @(posedge clk);
         dequeue   = 1'b1;
      end
      // stop reading
      @(posedge clk);
      dequeue = 1'b0;

      // fill the FIFO to 'full' and check blocking of writes
      $display("[TB] Fill FIFO test");
      // write until full
      fork
         begin
            // keep writing data
            enqueue   = 1'b1;
            while (!full) begin
               @(posedge clk);
               wr_data = wr_data + 1'b1;
            end
            enqueue = 1'b0; // once full, stop writing
            $display("   FIFO is FULL at time %t", $time);
         end
      join

      $display("[TB] Drain FIFO test");
      // now read everything until empty
      dequeue   = 1'b1;
      while (!empty) begin
         @(posedge clk);
      end
      dequeue = 1'b0;
      $display("   FIFO is EMPTY at time %t", $time);

      // wrap-around check
      // write more than DEPTH items in multiple bursts, and read them back
      $display("[TB] Wrap-around test");
      for (integer i = 0; i < DEPTH+2; i++) begin
         @(posedge clk);
         enqueue = 1'b1;
         wr_data = 32'(i); 
      end
      // stop writing
      @(posedge clk);
      enqueue = 1'b0;

      // read them back
      for (int i = 0; i < DEPTH+2; i++) begin
         @(posedge clk);
         dequeue = 1'b1;
      end
      @(posedge clk);
      dequeue = 1'b0;

      #(10);
      $display("[TB] Test complete!");
      $finish;
   end

   // monitor
   always_ff @(posedge clk) begin
      if (enqueue && !full) begin
         $display("%t WRITE: data=%0h tail=%0d",
            $time, wr_data, dut.tail);
      end
      if (dequeue && !empty) begin
         $display("%t READ : data=%0h head=%0d",
            $time, rd_data, dut.head);
      end
   end


endmodule : FIFO_tb