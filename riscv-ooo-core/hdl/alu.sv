module alu 
import rv32i_types::*;
(
    // input logic clk,
    // input logic rst,
    input decode_rename_t inst_packet, // parts used: both operand values, aluop, comparator, cmpop, valid
    output logic [31:0] aluout,
    output logic branch,
    output logic valid
);

logic signed    [31:0]  as;
logic signed    [31:0]  bs;
logic unsigned  [31:0]  au;
logic unsigned  [31:0]  bu;

logic unsigned [31:0] inst, b_imm;

logic br_en; // not used for branches here, just comparator outputs

always_comb begin
    as = signed'(inst_packet.rs1_data);
    bs = signed'(inst_packet.rs2_data);
    au = unsigned'(inst_packet.rs1_data);
    bu = unsigned'(inst_packet.rs2_data);

    valid = inst_packet.valid;
    inst = inst_packet.instruction;
    b_imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};

    unique case (inst_packet.cmpop)
        branch_f3_blt : br_en = (as <  bs);
        branch_f3_bltu: br_en = (au <  bu);
        default       : br_en = 1'bx;
    endcase

    if (inst_packet.comparator)
        aluout = {31'b0, br_en}; // for slt, sltu instructions
    else begin
        if (inst_packet.branch) begin
            if (inst_packet.jal == 2'b0)
                aluout = inst_packet.pc + b_imm;
            else if (inst_packet.jal == 2'b01)
                aluout = inst_packet.pc + bu; // rs2 = j_imm
            else
                aluout = au + bu; // rs2 = i_imm
        end else begin
            unique case (inst_packet.aluop)
                alu_op_add: aluout = au +   bu;
                alu_op_sll: aluout = au <<  bu[4:0];
                alu_op_sra: aluout = unsigned'(as >>> bu[4:0]);
                alu_op_sub: aluout = au -   bu;
                alu_op_xor: aluout = au ^   bu;
                alu_op_srl: aluout = au >>  bu[4:0];
                alu_op_or : aluout = au |   bu;
                alu_op_and: aluout = au &   bu;
                default   : aluout = 'x;
            endcase 
        end       
    end
    branch = inst_packet.branch;
end

endmodule : alu