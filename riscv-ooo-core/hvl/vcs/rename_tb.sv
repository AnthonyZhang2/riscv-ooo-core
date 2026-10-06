`timescale 1ns/1ps

module rename_tb;
  initial begin
      $fsdbDumpfile("dump.fsdb");
      $fsdbDumpvars(0, "+all");
  end

  import rv32i_types::*;

  // paras
  localparam integer NUM_ROB_ENTRIES = 8;

  logic clk;
  logic rst;

  // decode stage
  decode_rename_t dec_in;
  logic           dec_valid;
  logic           dec_ready;

  // to RS
  RS_Entry        rs_out;
  logic           rs_valid;
  logic           rs_full;

  // to/from ROB
  instr_variants  rob_instr_type;
  logic [4:0]     rob_dest_arch;
  logic [63:0]    rob_order;
  logic           rob_input_valid;

  logic           rob_full;
  logic [$clog2(NUM_ROB_ENTRIES)-1:0] rob_tail_idx;

  // init rename station
  rename_station #(.NUM_ROB_ENTRIES(NUM_ROB_ENTRIES)) 
  u_rename (
    .clk              (clk),
    .rst              (rst),

    .dec_in           (dec_in),
    .dec_valid        (dec_valid),
    .dec_ready        (dec_ready),

    .rs_out           (rs_out),
    .rs_valid         (rs_valid),
    .rs_full          (rs_full),

    .rob_instr_type   (rob_instr_type),
    .rob_dest_arch    (rob_dest_arch),
    .rob_order        (rob_order),
    .rob_input_valid  (rob_input_valid),

    .rob_full         (rob_full),
    .rob_tail_idx     (rob_tail_idx)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // seq test
  integer cycle;

  initial begin
    $display("======== Start rename_station Test ==========");
    rst         = 1'b1;
    dec_valid   = 1'b0;
    rs_full     = 1'b0;
    rob_full    = 1'b0;
    rob_tail_idx= '0;
    // dec_in default
    dec_in      = '0;

    @(posedge clk); 
    @(posedge clk);
    rst = 1'b0;
    @(posedge clk);

    // 1) basic insertion 
    // feed 3 instructions in a row, with no stalls
    feed_instruction(32'h0000_0033, 5'd1, 5'd2, 5'd8, 100); // something with opcode=op_b_reg
    feed_instruction(32'h0000_0063, 5'd3, 5'd4, 5'd9, 101); // opcode=op_b_br
    feed_instruction(32'h0000_0013, 5'd5, 5'd6, 5'd10,102); // opcode=op_b_imm
    // pass them
    repeat(5) @(posedge clk);

    // 2) stall by ROB full 
    $display("** Testing ROB FULL stall...");
    rob_full = 1'b1;
    feed_instruction(32'h0000_0073,5'd2,5'd1,5'd11,200); // tries to push but can't
    repeat(3) @(posedge clk);

    // now release stall
    rob_full = 1'b0;
    repeat(2) @(posedge clk);

    // 3) stall by RS full
    $display("** Testing RS FULL stall...");
    rs_full = 1'b1;
    feed_instruction(32'h0000_0073,5'd2,5'd1,5'd12,201); 
    repeat(3) @(posedge clk);

    // release RS stall
    rs_full = 1'b0;
    repeat(2) @(posedge clk);

    // 4) another instruction
    feed_instruction(32'h0000_0113,5'd10,5'd0,5'd13,300);
    repeat(5) @(posedge clk);

    $display("======== Finished rename_station Test ==========");
    $finish;
  end

  //  Driving instructions helper
  task feed_instruction(
    input [31:0] inst,
    input [4:0]  rs1,
    input [4:0]  rs2,
    input [4:0]  rd,
    input [63:0] order
  );
    begin
      @(posedge clk);
      dec_in.instruction = inst;
      dec_in.rs1_addr    = rs1;
      dec_in.rs2_addr    = rs2;
      dec_in.rd_addr     = rd;
      dec_in.order       = order;
      dec_in.use_rs1     = 1'b1;
      dec_in.use_rs2     = (rs2!=5'd0);
      dec_in.rs1_ready   = 1'b1; // pretend decode knows data is ready
      dec_in.rs2_ready   = 1'b1; 
      dec_in.rs1_data    = 32'hAAAA_0000 | rs1; 
      dec_in.rs2_data    = 32'hBBBB_0000 | rs2;
      dec_in.valid       = 1'b1;

      dec_valid = 1'b1;
      rob_tail_idx= rob_tail_idx + 1'b1; // increment for next instruction

      // wait at least 1 cycle 
      // if we are stalling, we'll hold it. Otherwise, we drop after 1 cycle
      @(posedge clk);
      while (!dec_ready) begin
         // if rename can't accept, we keep the same instruction valid
         @(posedge clk);
      end
      dec_valid = 1'b0; // done
      dec_in = '0;
    end
  endtask

  // monitor signals
  always_ff @(posedge clk) begin
    if (!rst) begin
      // RS output 
      if (rs_valid) begin
        $display("%t [TB] RS_OUT: busy=%b opcode=0x%0h Qj=%0d Qk=%0d dest=%0d rob_addr=%0d", 
          $time, rs_out.busy, rs_out.opcode, rs_out.Qj, rs_out.Qk, rs_out.dest, rs_out.rob_address);
      end
      // ROB output
      if (rob_input_valid) begin
        $display("%t [TB] ROB_OUT: instr_type=%0s dest=%0d order=%0d tail_idx=%0d", 
          $time, instr_variant_name(rob_instr_type), rob_dest_arch, rob_order, rob_tail_idx);
      end
      // decode
      if (dec_valid) begin
        $display("%t [TB] DEC_IN: opcode=0x%0h rs1=%0d rs2=%0d rd=%0d order=%0d dec_ready=%b", 
          $time, dec_in.instruction[6:0], dec_in.rs1_addr, dec_in.rs2_addr, dec_in.rd_addr, dec_in.order, dec_ready);
      end
    end
  end

  // helper function to print instr_variants
  function string instr_variant_name (input instr_variants v);
    case (v)
      r_type  : instr_variant_name = "R_TYPE";
      i_type  : instr_variant_name = "I_TYPE";
      s_type  : instr_variant_name = "S_TYPE";
      b_type  : instr_variant_name = "B_TYPE";
      u_type  : instr_variant_name = "U_TYPE";
      j_type  : instr_variant_name = "J_TYPE";
      invalid : instr_variant_name = "INVALID";
      default : instr_variant_name = "???";
    endcase
  endfunction

endmodule
