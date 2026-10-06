module division_unit 
import rv32i_types::*;
(
    input  logic                 clk,
    input  logic                 rst,
    input  logic                 inst_hold,
    input  logic                 inst_start,
    input  logic [31:0]          a,
    input  logic [31:0]          b,
    input  logic [6:0]           opcode,
    input  logic [2:0]           funct3,

    output logic                 complete_inst,
    output logic [31:0]          div_out
);

logic unsigned_complete;
logic unsigned_div0;
logic [31:0] unsigned_quotient;
logic [31:0] unsigned_remainder;

logic signed_complete;
logic signed_div0;
logic [31:0] signed_quotient;
logic [31:0] signed_remainder;

// Instance of DW_div_seq for signed division
DW_div_seq #(
    .a_width      (32),
    .b_width      (32),
    .tc_mode      (1), // Signed mode
    .num_cyc      (3),
    .rst_mode     (1), // Synchronous reset to match rest of CPU
    .input_mode   (1),
    .output_mode  (1),
    .early_start  (0)
) signed_division (
    .clk          (clk),
    .rst_n        (~rst),
    .hold         (inst_hold),
    .start        (inst_start),
    .a            (a),
    .b            (b),
    .complete     (signed_complete),
    .divide_by_0  (signed_div0),
    .quotient     (signed_quotient),
    .remainder    (signed_remainder)
);

// Instance of DW_div_seq
DW_div_seq #(
    .a_width      (32),
    .b_width      (32),
    .tc_mode      (0), //unsigned mode
    .num_cyc      (3),
    .rst_mode     (1), //Synchronous reset to match rest of CPU
    .input_mode   (1),
    .output_mode  (1),
    .early_start  (0)
) unsigned_division (
    .clk          (clk),
    .rst_n        (~rst),
    .hold         (inst_hold),
    .start        (inst_start),
    .a            (a),
    .b            (b),
    .complete     (unsigned_complete),
    .divide_by_0  (unsigned_div0),
    .quotient     (unsigned_quotient),
    .remainder    (unsigned_remainder)
);


always_comb begin
    unique case (funct3)
        muldiv_f3_div: begin
            complete_inst = signed_complete;
            if(signed_div0) 
                div_out = 32'hFFFFFFFF;
            else 
                div_out = signed_quotient;
        end
        muldiv_f3_divu: begin
            complete_inst = unsigned_complete;
            if(unsigned_div0) 
                div_out = 32'hFFFFFFFF;
            else 
                div_out = unsigned_quotient;
        end
        muldiv_f3_rem: begin
            complete_inst = signed_complete;
            div_out = signed_remainder;
        end
        muldiv_f3_remu: begin
            complete_inst = unsigned_complete;
            div_out = unsigned_remainder;
        end
        default: begin
            complete_inst = 1'b0;
            div_out = 'x;
        end
    endcase
end

endmodule : division_unit