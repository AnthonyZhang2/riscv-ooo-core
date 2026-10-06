module muldiv_unit
import rv32i_types::*;
(
    input  logic                          clk,
    input  logic                          rst,
    input  logic                          inst_hold,
    input  logic                          inst_start,
    input decode_rename_t                 input_packet,

    output logic                          complete_inst,
    output decode_rename_t                output_packet,
    output logic [31:0]                   data_out,
    input logic [4:0] rob_addr_in,
    output logic [4:0] rob_addr_out
);

logic [32:0] a, b;
logic a_msb, b_msb;
logic [65:0] mul_product;

logic [32:0] div_quotient, div_remainder;
logic div0;

logic start_pulse, temp_pulse;
logic [4:0] delayed_ROB;
 
assign temp_pulse = inst_start & (~start_pulse || (delayed_ROB != rob_addr_in));

always_ff @(posedge clk) begin
    if (rst) begin
        start_pulse <= 1'b0;
        delayed_ROB <= 5'd0;
    end else begin
        start_pulse <= inst_start;
        delayed_ROB <= rob_addr_in;
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        output_packet <= '0;
        rob_addr_out <= '0;
    end else if (inst_start) begin
        output_packet <= input_packet;
        rob_addr_out <= rob_addr_in;
    end
end

always_comb begin
    unique case (input_packet.aluop)
        muldiv_f3_mul: begin //signed x signed
            a_msb = input_packet.rs1_data[31];
            b_msb = input_packet.rs2_data[31];

            data_out = mul_product[31:0];
        end
        muldiv_f3_mulh: begin  //signed x signed
            a_msb = input_packet.rs1_data[31];
            b_msb = input_packet.rs2_data[31];

            data_out = mul_product[63:32];
        end
        muldiv_f3_mulhsu: begin  //signed x unsigned
            a_msb = input_packet.rs1_data[31];
            b_msb = 1'b0;

            data_out = mul_product[63:32];
        end
        muldiv_f3_mulhu: begin  //unsigned x unsigned
            a_msb = 1'b0;
            b_msb = 1'b0;

            data_out = mul_product[63:32];
        end
        muldiv_f3_div: begin //signed / signed
            a_msb = input_packet.rs1_data[31];
            b_msb = input_packet.rs2_data[31];

            if (!div0) begin
                data_out = div_quotient[31:0];
            end else begin
                data_out = 32'hFFFFFFFF;
            end
        end
        muldiv_f3_divu: begin //unsigned / unsigned
            a_msb = 1'b0;
            b_msb = 1'b0;

            if (!div0) begin
                data_out = div_quotient[31:0];
            end else begin
                data_out = 32'hFFFFFFFF;
            end
        end
        muldiv_f3_rem: begin //signed % signed
            a_msb = input_packet.rs1_data[31];
            b_msb = input_packet.rs2_data[31];

            data_out = div_remainder[31:0];
        end
        muldiv_f3_remu: begin //unsigned % unsigned
            a_msb = 1'b0;
            b_msb = 1'b0;

            data_out = div_remainder[31:0];
        end
        default: begin
            a_msb = '0;
            b_msb = '0;

            data_out = 32'd0;
        end
    endcase

    a = {a_msb, input_packet.rs1_data};
    b = {b_msb, input_packet.rs2_data};
end


DW_mult_seq #(
    .a_width      (33),
    .b_width      (33),
    .tc_mode      (1), //signed
    .num_cyc      (3),
    .rst_mode     (0), //Synchronous reset to match rest of CPU
    .input_mode   (1),
    .output_mode  (1),
    .early_start  (0)
) signed_mul (
    .clk       (clk),
    .rst_n     (~rst),
    .hold      (inst_hold),
    .start     (temp_pulse),
    .a         (a),
    .b         (b),
    .complete  (complete_inst),
    .product   (mul_product)
);

// Instance of DW_div_seq for signed division
DW_div_seq #(
    .a_width      (33),
    .b_width      (33),
    .tc_mode      (1), // Signed mode
    .num_cyc      (3),
    .rst_mode     (0), // Synchronous reset to match rest of CPU
    .input_mode   (1),
    .output_mode  (1),
    .early_start  (0)
) signed_division (
    .clk          (clk),
    .rst_n        (~rst),
    .hold         (inst_hold),
    .start        (temp_pulse),
    .a            (a),
    .b            (b),
    .complete     (),
    .divide_by_0  (div0),
    .quotient     (div_quotient),
    .remainder    (div_remainder)
);

endmodule : muldiv_unit