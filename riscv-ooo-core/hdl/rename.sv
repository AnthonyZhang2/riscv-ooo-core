module rename_station
import rv32i_types::*;
#(
    parameter integer NUM_ROB_ENTRIES =  32    // temp match reorder.sv
)(
    // input  logic           clk,
    // input  logic           rst,

    // from decode stage
    input  decode_rename_t dec_in,
    output logic           dec_ready,

    // from res station
    output RS_Entry        rs_out, // only pass one RS entry, valid bits to determine which RS is used
    output logic           rs_valid_alu,
    output logic           rs_valid_muldiv,
    output logic           rs_valid_loadstore,
    input  logic           rs_full_alu,         // 1 = RS cannot accept
    input logic            rs_full_muldiv,
    input logic            rs_full_loadstore,

    // to / from ROB
    output logic           rob_input_valid, // push new entry
   
    input  logic           rob_full, 
    input  logic [$clog2(NUM_ROB_ENTRIES)-1:0]  rob_tail_idx,

    input cdb_t cdb, commit_bus,
    // to regfile
    output logic [4:0] rename_s,
    output regfile_entry_t rename_v,
    input regfile_entry_t rename_v_r,
    output logic rename_we
);  

    logic dec_valid;
    assign dec_valid = dec_in.valid;
    
    // stall logic
    logic rs_full;

    always_comb begin
        unique case(dec_in.functional_unit)
            fu_alu: rs_full = rs_full_alu;
            fu_muldiv: rs_full = rs_full_muldiv;
            fu_mem: rs_full = rs_full_loadstore;
            fu_control: rs_full = rs_full_alu; //We also use ALU for control instr
            default: rs_full = 1'd1; //Assume full
        endcase
    end

   //assign rs_full = (dec_in.functional_unit == fu_alu) ? rs_full_alu : rs_full_muldiv;
    logic can_accept;
    assign can_accept = (!rob_full) && (!rs_full);
    assign dec_ready = can_accept;

    assign rs_valid_alu = dec_valid && can_accept && (dec_in.functional_unit == fu_alu);
    assign rs_valid_muldiv = dec_valid && can_accept && (dec_in.functional_unit == fu_muldiv);
    assign rob_input_valid = dec_valid && can_accept;

    assign rs_valid_loadstore = dec_valid && can_accept && (dec_in.functional_unit == fu_mem);

    logic [6:0] opcode; 

    // build RS entry
    RS_Entry comb_rs_out;

    always_comb begin
        comb_rs_out = '0;

        if (dec_valid && can_accept) begin
            comb_rs_out.busy       = 1'b1;

            comb_rs_out.instruction_packet = dec_in;

            if (dec_in.use_rs1 & !(dec_in.rs1_ready) & cdb.valid & cdb.rob_idx == dec_in.rs1_data[4:0]) begin // check CDB for register data, waiting registers have rob_addr in data[4:0] (see decode)
                comb_rs_out.instruction_packet.rs1_ready = '1;
                comb_rs_out.instruction_packet.rs1_data = cdb.exec_result;
            end else if (dec_in.use_rs1 & !(dec_in.rs1_ready) & commit_bus.valid & commit_bus.rob_idx == dec_in.rs1_data[4:0]) begin // check CDB for register data, waiting registers have rob_addr in data[4:0] (see decode)
                comb_rs_out.instruction_packet.rs1_ready = '1;
                comb_rs_out.instruction_packet.rs1_data = commit_bus.exec_result;
            end
            if (dec_in.use_rs2 & !(dec_in.rs2_ready) & cdb.valid & cdb.rob_idx == dec_in.rs2_data[4:0]) begin
                comb_rs_out.instruction_packet.rs2_ready = '1;
                comb_rs_out.instruction_packet.rs2_data = cdb.exec_result;
            end else if (dec_in.use_rs2 & !(dec_in.rs2_ready) & commit_bus.valid & commit_bus.rob_idx == dec_in.rs2_data[4:0]) begin
                comb_rs_out.instruction_packet.rs2_ready = '1;
                comb_rs_out.instruction_packet.rs2_data = commit_bus.exec_result;
            end

            comb_rs_out.rob_address = rob_tail_idx;          
            
        end

        rename_s = dec_in.rd_addr;
        rename_v.renamed = '1;
        rename_v.value = rename_v_r.value;
        rename_v.rob_addr = rob_tail_idx;
        rename_we = dec_valid & can_accept;

        rs_out = comb_rs_out;
    end

endmodule
