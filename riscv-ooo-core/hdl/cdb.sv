module cdb 
import rv32i_types::*;
#(
    parameter integer NUM_ROB_ENTRIES=32
)
(
    input logic clk,
    input logic rst,

    input logic [31:0] alu_out,
    input logic alu_valid,
    input logic [$clog2(NUM_ROB_ENTRIES)-1:0] alu_rob_idx,
    input decode_rename_t alu_packet,

    input logic [31:0] muldiv_out,
    input logic muldiv_valid,
    input logic [$clog2(NUM_ROB_ENTRIES)-1:0] muldiv_rob_idx,
    input decode_rename_t muldiv_packet,

    input logic [31:0] mem_out,
    input logic mem_valid,
    input logic [$clog2(NUM_ROB_ENTRIES)-1:0] mem_rob_idx,
    input decode_rename_t mem_packet,

    input logic branch,

    output cdb_t cdb_out,

    output logic stall_muldiv,

    output logic alu_complete,
    output logic muldiv_complete,
    output logic mem_complete,
    output logic delayed_muldiv_valid
);
assign stall_muldiv = mem_valid & muldiv_valid;

always_ff @(posedge clk) begin
    if (rst) 
        delayed_muldiv_valid <= '0;
    else begin
        if (muldiv_valid & mem_valid)
            delayed_muldiv_valid <= '1;
        else
            delayed_muldiv_valid <= '0;
    end
end

always_ff @(posedge clk) begin

    if (rst) begin
        cdb_out <= '0;

        alu_complete <= 1'b0;
        muldiv_complete <= 1'b0;
        mem_complete <= 1'b0;
        // stall_muldiv <= 1'b0;
    end else begin
        alu_complete <= 1'b0;
        muldiv_complete <= 1'b0;
        mem_complete <= 1'b0;
        // stall_muldiv <= 1'b0;

        if (mem_valid) begin   
            mem_complete <= 1'b1;

            cdb_out.valid <= 1'b1;
            cdb_out.exec_result <= mem_out;
            cdb_out.rob_idx <= mem_rob_idx;
            cdb_out.instruction_packet <= mem_packet;
            cdb_out.branch <= '0;

            // stall_muldiv <= muldiv_valid;

        end else if ((muldiv_valid | delayed_muldiv_valid) & !muldiv_complete) begin
            muldiv_complete <= 1'b1;

            cdb_out.valid <= 1'b1;
            cdb_out.exec_result <= muldiv_out;
            cdb_out.rob_idx <= muldiv_rob_idx;
            cdb_out.instruction_packet <= muldiv_packet;
            cdb_out.branch <= '0;
        
        end else if (alu_valid) begin
            alu_complete <= 1'b1;

            cdb_out.valid <= 1'b1;
            cdb_out.exec_result <= alu_out;
            cdb_out.rob_idx <= alu_rob_idx;
            cdb_out.instruction_packet <= alu_packet;
            cdb_out.branch <= branch;
        
        end else begin
            cdb_out <= '0;
        end
    end
end


endmodule : cdb