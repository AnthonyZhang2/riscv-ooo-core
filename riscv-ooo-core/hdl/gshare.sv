module gshare 
import rv32i_types::*;
#(
    parameter integer GHR_WIDTH = 32,
    parameter integer WIDTH_T1   = 10
)(
    input logic clk,
    input logic rst,
    
    input logic [31:0] pc,

    input cdb_t commit_bus,

    output logic predicted_branch,
    output tage_info predictor_info
); 




logic web_t1;



logic [GHR_WIDTH-1:0] ghr; //Global History Register, 1 for branch taken and 0 for branch not taken


logic mispredicted;
assign mispredicted = (commit_bus.instruction_packet.taken_branch != commit_bus.instruction_packet.predicted_branch);


// ***************************************************************************************
//                                  TABLE 1 DECLARATIONS
// ***************************************************************************************


logic [2:0] t1 [1024];

logic [2:0] t1_in, t1_out;


logic [9:0] t1_idx, t1_commit_idx;


assign t1_idx = pc[0+:WIDTH_T1] ^ ghr[0+:WIDTH_T1] ^ pc[31-:WIDTH_T1];


assign t1_commit_idx = commit_bus.instruction_packet.tage_info.t1_idx;



// sp_ff_array #(
//     .S_INDEX(11), .WIDTH(3)
// ) table_1 (
//     .clk0       (clk),
//     .rst0       (rst),
//     .csb0       ('0),
//     .web0       (web_t1),
//     .addr0      ((web_t1) ? t1_idx : t1_commit_idx),
//     .din0       (t1_in),
//     .dout0      (t1_out)
// );


// ***************************************************************************************
//                          GLOBAL HISTORY REGISTER UPDATE
// ***************************************************************************************
always_ff @(posedge clk) begin 
    if (rst) begin
        ghr <= '0;
    end else if (commit_bus.valid && commit_bus.instruction_packet.branch) begin
        ghr <= {ghr[GHR_WIDTH-2:0], commit_bus.instruction_packet.taken_branch};
    end
end

// ***************************************************************************************
//                                TABLE INITIALIZATION
// ***************************************************************************************

always_comb begin
    web_t1 = '0;
    if (commit_bus.valid && commit_bus.instruction_packet.branch) begin
        web_t1 = '1;
    end 
end 

always_ff @(posedge clk) begin
    if (rst) begin
        for(integer i = 0; i < 1024; i++) begin
            t1[i] <= 3'd3;
        end

    end else begin
        if (commit_bus.valid && commit_bus.instruction_packet.branch) begin
            if (commit_bus.instruction_packet.taken_branch) begin
                if(t1[t1_commit_idx] == 7)
                   t1[t1_commit_idx] <= 3'd7;
                else 
                   t1[t1_commit_idx] <= t1[t1_commit_idx] + 3'd1;
            end else begin
                if(t1[t1_commit_idx] == 0)
                    t1[t1_commit_idx] <= 3'd0;
                else 
                    t1[t1_commit_idx] <= t1[t1_commit_idx] - 3'd1;
            end
            if (mispredicted) begin 
                if (commit_bus.instruction_packet.taken_branch)
                    t1[t1_commit_idx] <= 3'd3; //strongly taken
                else
                    t1[t1_commit_idx] <= 3'd2; //strongly not taken
            end
        end
    end
end

always_comb begin
    predicted_branch = 1'b0;
    predictor_info.provider_id = 3'd0;
    predictor_info.t1_idx = t1_idx; //Left over from TAGE
    predictor_info.t1_tag = '0;
    predictor_info.t2_idx = '0;
    predictor_info.t2_tag = '0;
    predictor_info.t3_idx = '0;
    predictor_info.t3_tag = '0;

    if (t1[t1_idx] >= 3) begin
        predicted_branch = 1'b1;
    end 

end

endmodule : gshare
