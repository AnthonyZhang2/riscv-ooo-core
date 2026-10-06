module FIFO #(
    parameter integer DATA_WIDTH = 32,
    parameter integer DEPTH      = 8
)(
    input  logic                  clk,
    input  logic                  rst,

    input  logic                  enqueue,      // enqueue request
    input  logic [DATA_WIDTH-1:0] wr_data,

    input  logic                  dequeue,      // dequeue request
    output logic [DATA_WIDTH-1:0] rd_data,

    output logic                  full,
    output logic                  empty
);

   localparam PTR_WIDTH = $clog2(DEPTH) + 1; 

   logic [DATA_WIDTH-1:0] queue [0:DEPTH-1];
   logic [PTR_WIDTH-1:0] head, tail;

   assign empty = (head == tail);
   assign full  = (head[PTR_WIDTH-1] != tail[PTR_WIDTH-1]) &&
                  (head[PTR_WIDTH-2:0] == tail[PTR_WIDTH-2:0]);

   // read data output storage
   logic [DATA_WIDTH-1:0] rd_data_reg;
   assign rd_data = rd_data_reg;
//    assign rd_data = queue[head[PTR_WIDTH-2:0]];
   always_ff @(posedge clk) begin
       if (rst) begin
           head     <= '0;
           tail     <= '0;
           rd_data_reg <= '0;
           for (integer i = 0; i < DEPTH; i++) begin
                queue[i] <= '0;
           end
       end else begin
           // dequeue
           if (dequeue && !empty) begin
               rd_data_reg <= queue[head[PTR_WIDTH-2:0]];
               // head++
               head      <= head + 1'b1;
           end else if (dequeue & empty) rd_data_reg <= '0;
        //    end

           // enqueue
           if (enqueue && !full) begin
               queue[tail[PTR_WIDTH-2:0]] <= wr_data;
               // tail++
               tail <= tail + 1'b1;
           end
       end
   end

endmodule