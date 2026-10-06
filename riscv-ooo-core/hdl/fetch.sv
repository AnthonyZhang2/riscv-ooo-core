module fetch 
import rv32i_types::*;
(
    input logic clk, 
    input logic rst,
    input logic [255:0] icache_rdata, // need a modified instruction cache - read only, one bi t rmask, returns entire line
    input logic icache_resp,
    input logic fetch_backpressure, // high when instruction queue is full, stalls fetching

    input cdb_t commit_bus,

    output logic icache_rmask, // 1 by te instruction cache rmask when instruction not in linebuffer

    // input regfile_entry_t fetch_v_r, //Forwarding register values for JALR
    // output logic [4:0] fetch_s,
    output iqueue_entry_t fetch_out
);

logic [31:0] pc, pc_next, inst_data;
logic fetch_resp;

logic [255:0] linebuffer;
logic [31:5] linebuffer_tag;
logic tag_match;
logic [63:0] order, order_next;

logic delayed_branch;

logic predicted_branch;
logic [31:0] predicted_pc;
tage_info predictor_info;

logic [63:0] total_branch_predictions; //Used for debugging and measure prediction correctness
logic [63:0] misprediction_counter; 

logic tage_used; //Debugging only

// tage_predictor branch_predictor(
//     .clk(clk),
//     .rst(rst),

//     .pc(pc), // pc gets hgiher IPC than pc_next
//              //pc_next causes infinite loop and pc+32'd4 is worse
//     .commit_bus(commit_bus),

//     .predicted_branch(predicted_branch),
//     .predictor_info(predictor_info)
// );

gshare branch_predictor(
    .clk(clk),
    .rst(rst),

    .pc(pc), // pc gets hgiher IPC than pc_next
             //pc_next causes infinite loop and pc+32'd4 is worse
    .commit_bus(commit_bus),

    .predicted_branch(predicted_branch),
    .predictor_info(predictor_info)
);

always_ff @(posedge clk) begin //Count Mispredictions
    if (rst) begin
        misprediction_counter <= 64'd0;
        total_branch_predictions <= 64'd0;
    end else begin
        if (commit_bus.valid && commit_bus.instruction_packet.branch)
            total_branch_predictions <= total_branch_predictions + 64'd1;
        if (commit_bus.valid && commit_bus.branch) begin
            misprediction_counter <= misprediction_counter + 64'd1;
        end
    end
end

always_ff @(posedge clk) begin
    if (rst) delayed_branch <= '0;
    else delayed_branch <= commit_bus.branch;
end

    always_ff @(posedge clk) begin // pc register
        if (rst) begin
            pc <= 32'hAAAAA000;
            order <= '0;
        end else begin
            pc <= pc_next;
            order <= order_next;
        end
    end

    always_ff @(posedge clk) begin // linebuffer
        if (rst) begin
            linebuffer <= '0;
            linebuffer_tag <= '0;
        end else begin
            if (icache_resp & !delayed_branch) begin // linebuffer updates on every response from cache
                linebuffer <= icache_rdata;
                linebuffer_tag <= pc[31:5];
            end
        end
    end


    always_comb begin
        tag_match = (pc[31:5] == linebuffer_tag);
        fetch_resp = (tag_match | (icache_resp & !delayed_branch)) & (!fetch_backpressure); // high for 1 cycle when instruction is ready and no backpressure
        icache_rmask = !(tag_match | rst); // always read from cache on tag mismatch, linebuffer can be updated even when queue is full
        pc_next = pc;
        order_next = order;
        tage_used = '0;
        if (!commit_bus.branch && fetch_resp) begin
            pc_next = pc + 4; // increment pc when instruction is placed in queue
            order_next = order + 1;
        end
        else if (commit_bus.branch && commit_bus.valid) begin
            pc_next = commit_bus.instruction_packet.pc_next; // exec_result != pc_next for jal instructions
            order_next = commit_bus.instruction_packet.order + 1;
        end

        if (tag_match)
            inst_data = linebuffer[pc[4:2] * 32 +: 32];        
        else if (icache_resp)
            inst_data = icache_rdata[pc[4:2] * 32 +: 32];
        else
            inst_data = '0;

        fetch_out.tage_info = '0;
        // fetch_s = '0;


        if (inst_data[6:0] == 7'h6F && fetch_resp && !commit_bus.branch) begin //JAL instruction
            fetch_out.predicted_branch = 1'b1;
            pc_next = pc + {{12{inst_data[31]}}, inst_data[19:12], inst_data[20], inst_data[30:21], 1'b0};    

        // end else if (inst_data[6:0] == 7'h67 && fetch_resp && !commit_bus.branch) begin //JALR with forwarding
        //     fetch_s = inst_data[19:15];
        //     if (!fetch_v_r.renamed) begin
        //         fetch_out.predicted_branch = 1'b1;
        //         pc_next = pc + fetch_v_r.value + {{21{inst_data[31]}}, inst_data[30:20]};
        //     end
        end else if (inst_data[6:0] == 7'h63 && fetch_resp && !commit_bus.branch) begin //BR instruction
            tage_used = 1'b1;
            if (predicted_branch) begin
                pc_next = pc + {{20{inst_data[31]}}, inst_data[7], inst_data[30:25], inst_data[11:8], 1'b0};
                fetch_out.predicted_branch = 1'b1;
            end else begin
                pc_next = pc + 4;
                fetch_out.predicted_branch = 1'b0;
            end
            fetch_out.tage_info = predictor_info;
        end else begin
            fetch_out.predicted_branch = 1'b0;
        end
        
        
            
        fetch_out.pc = pc;
        fetch_out.pc_next = pc_next;
        fetch_out.instruction = inst_data;
        
        fetch_out.valid = fetch_resp;
        fetch_out.order = order;
    end

endmodule : fetch