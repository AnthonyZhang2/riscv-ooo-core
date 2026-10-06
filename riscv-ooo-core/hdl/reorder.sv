module reorder
import rv32i_types::*;
#(
    parameter integer NUM_ROB_ENTRIES=32
)
(
    input logic clk,
    input logic rst,

    // Add Instruction to ROB
    input logic input_valid, //Tells there's a new input that's valid, sent from decode

    input cdb_t data_bus,
    output cdb_t commit_bus,
    
    // input logic flush,

    output logic [4:0] commit_dest,
    output logic commit_valid,

    output regfile_entry_t commit_v_w, // this is written to the regfile, so commit.sv not needed
    input regfile_entry_t commit_v_r, // this is read from the regfile to see if register has already been renamed

    output logic full,
    
    output logic [$clog2(NUM_ROB_ENTRIES)-1:0] tail_out,
    output logic [4:0] head_out
);

localparam integer HEAD_PTR_WIDTH = $clog2(NUM_ROB_ENTRIES);

// logic branch_taken;
logic [31:0] commit_result;

integer flush_index;

rob_entry_t rob [NUM_ROB_ENTRIES]; 
logic [HEAD_PTR_WIDTH:0] head, tail;

logic should_branch;
logic branch_taken;

decode_rename_t commit_packet;

//assign branch_taken     = branch_taken_reg;

/*******************************************************************************
                        Reorder Buffer Management
 *******************************************************************************/

assign full = (head[5] != tail[5]) & (head[4:0] == tail[4:0]);

always_ff @(posedge clk) begin
    if (rst) begin
        for (integer i = 0; i < NUM_ROB_ENTRIES; i++) begin
            rob[i] <= '0;
        end
        head <= '0;
        tail <= '0;

        
    end else begin

        if (input_valid && !full) begin
            rob[tail[4:0]].valid        <= 1'b1;
            rob[tail[4:0]].done         <= 1'b0;
            rob[tail[4:0]].instruction_packet <= '0;
            rob[tail[4:0]].branch <= '0;
            tail <= tail + 6'b1;
        end
        if (data_bus.valid && rob[data_bus.rob_idx].valid) begin
            rob[data_bus.rob_idx].done <= 1'b1;
            rob[data_bus.rob_idx].result <= data_bus.exec_result;
            rob[data_bus.rob_idx].instruction_packet <= data_bus.instruction_packet;
            rob[data_bus.rob_idx].branch <= data_bus.branch;
        end
        if (rob[head[4:0]].valid && rob[head[4:0]].done) begin //Commit and send the values to commit
            rob[head[4:0]].valid <= 1'b0; 
            if (branch_taken) begin
                for (integer i = 0; i < NUM_ROB_ENTRIES; i++) begin 
                    rob[i] <= '0;
                end
                tail <= head + 6'b1;
            end
            head <= head + 6'b1;
        end
    end
end

always_comb begin // regfile write
    commit_result = rob[head[4:0]].result;
    if (rob[head[4:0]].instruction_packet.jal != 2'b0) begin
        commit_result = rob[head[4:0]].instruction_packet.pc_next; // for jal and jalr, pc_next written to rd 
    end
    should_branch = '0;
    commit_packet = '0;
    branch_taken = '0;
    if (rob[head[4:0]].valid && rob[head[4:0]].done) begin
        commit_packet = rob[head[4:0]].instruction_packet;
        if (rob[head[4:0]].branch) begin
        //if (rob[head[4:0]].branch && rob[head[4:0]].instruction_packet.predicted_branch) begin
            if (rob[head[4:0]].instruction_packet.jal == 2'b0) begin
                unique case (rob[head[4:0]].instruction_packet.instruction[14:12])
                    branch_f3_blt: should_branch = (signed'(rob[head[4:0]].instruction_packet.rs1_data) < signed'(rob[head[4:0]].instruction_packet.rs2_data));
                    branch_f3_beq: should_branch = (rob[head[4:0]].instruction_packet.rs1_data == rob[head[4:0]].instruction_packet.rs2_data);
                    branch_f3_bne: should_branch = (rob[head[4:0]].instruction_packet.rs1_data != rob[head[4:0]].instruction_packet.rs2_data);
                    branch_f3_bge: should_branch = (signed'(rob[head[4:0]].instruction_packet.rs1_data) >= signed'(rob[head[4:0]].instruction_packet.rs2_data));
                    branch_f3_bltu: should_branch = ({1'b0,rob[head[4:0]].instruction_packet.rs1_data} < {1'b0,rob[head[4:0]].instruction_packet.rs2_data});
                    branch_f3_bgeu: should_branch = ({1'b0,rob[head[4:0]].instruction_packet.rs1_data} >= {1'b0,rob[head[4:0]].instruction_packet.rs2_data});
                    default: should_branch = '0;
                endcase
            end else
                should_branch = '1;
        end
    end
    commit_valid = commit_packet.valid;
    commit_dest = commit_packet.rd_addr;

    commit_packet.taken_branch = should_branch;

    if (should_branch != rob[head[4:0]].instruction_packet.predicted_branch) begin
        branch_taken = '1;
        commit_packet.pc_next = (should_branch) ? rob[head[4:0]].result : rob[head[4:0]].instruction_packet.pc + 32'd4;
    end
    
    commit_v_w.value = commit_result;
    commit_v_w.renamed = commit_v_r.renamed;
    if (commit_v_r.rob_addr == head[4:0]) 
        commit_v_w.renamed = 1'b0;
    commit_v_w.rob_addr = commit_v_r.rob_addr;

    tail_out = tail[4:0];
    head_out = head[4:0];

    commit_bus.valid = commit_valid;
    commit_bus.exec_result = commit_result;
    commit_bus.rob_idx = head[4:0];


    //if (branch_taken )
    commit_bus.branch = branch_taken;
    commit_bus.instruction_packet = commit_packet;

    
end

endmodule : reorder