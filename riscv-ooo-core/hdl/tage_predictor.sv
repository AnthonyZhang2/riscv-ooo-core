module tage_predictor 
import rv32i_types::*;
#(
    parameter integer GHR_WIDTH = 32,
    parameter integer WIDTH_T1   = 4,
    parameter integer WIDTH_T2   = 8,
    parameter integer WIDTH_T3   = 16,
    parameter integer TAG_WIDTH_T1   = 7,
    parameter integer TAG_WIDTH_T2   = 9,
    parameter integer TAG_WIDTH_T3   = 11
)(
    input logic clk,
    input logic rst,
    
    input logic [31:0] pc,

    input cdb_t commit_bus,

    output logic predicted_branch,
    output tage_info predictor_info
); 


logic [1:0] t0 [1024];


logic web_t1, web_t2, web_t3;



logic [GHR_WIDTH-1:0] ghr; //Global History Register, 1 for branch taken and 0 for branch not taken
logic [1:0] base_predictor; 

logic mispredicted;
assign mispredicted = (commit_bus.instruction_packet.taken_branch != commit_bus.instruction_packet.predicted_branch);


// ***************************************************************************************
//                                  TABLE 1 DECLARATIONS
// ***************************************************************************************

typedef struct packed {
    logic [2:0]  ctr;
    logic [TAG_WIDTH_T1-1:0]  tag;
    logic [1:0]  useful; //we use this to mark how many times we've used it. Only used really when tables are full
} t1_entry_t;

//t1_entry_t t1 [512];

t1_entry_t t1_in, t1_out;


logic [8:0]   t1_idx, t1_commit_idx;
logic [TAG_WIDTH_T1-1:0]   t1_tag, t1_commit_tag;

logic [3:0] t1_lower_hash, t1_upper_hash;

assign t1_lower_hash = pc[0+:WIDTH_T1] ^ ghr[0+:WIDTH_T1] ^ pc[31-:WIDTH_T1];
assign t1_upper_hash = pc[WIDTH_T1+1+:WIDTH_T1] ^ ghr[0+:WIDTH_T1] ^ pc[31-:WIDTH_T1];

assign t1_idx = {pc[WIDTH_T1*2+1]^ghr[0]^ghr[1]^ghr[2]^ghr[3], t1_upper_hash, t1_lower_hash};
//assign t1_idx = {pc[WIDTH_T1*2+1]^ghr[0], t1_upper_hash, t1_lower_hash};
assign t1_tag = pc[WIDTH_T1 +: TAG_WIDTH_T1] ^ ghr[WIDTH_T1 +: TAG_WIDTH_T1];

assign t1_commit_idx = commit_bus.instruction_packet.tage_info.t1_idx;
assign t1_commit_tag = commit_bus.instruction_packet.tage_info.t1_tag;

//index_4b = (branch_inst_pc[0 +: $clog2(DEPTH_FOUR)] ^ updated_ghr[0 +: $clog2(DEPTH_FOUR)]) ^ (branch_inst_pc[31 -: $clog2(DEPTH_FOUR)]);

logic                t1_match, t1_commit_match;
always_comb begin
    //t1_match = (t1[t1_idx].tag == t1_tag);
    t1_match = (t1_out.tag == t1_tag);
end

// ***************************************************************************************
//                                  TABLE 2 DECLARATIONS
// ***************************************************************************************

typedef struct packed {
    logic [2:0]  ctr;
    logic [TAG_WIDTH_T2-1:0]  tag;
    logic [1:0]  useful; //we use this to mark how many times we've used it. Only used really when tables are full
} t2_entry_t;

t2_entry_t t2_in, t2_out;


//t2_entry_t t2 [512];

logic [8:0] t2_idx, t2_commit_idx;
logic [TAG_WIDTH_T2-1:0] t2_tag, t2_commit_tag;

logic       t2_match, t2_commit_match;

logic [7:0] t2_hash;
assign t2_hash = pc[0+:WIDTH_T2] ^ ghr[0+:WIDTH_T2] ^ pc [31-:WIDTH_T2];

assign t2_idx = {pc[WIDTH_T2]^ghr[0]^ghr[1]^ghr[2]^ghr[3]^ghr[4]^ghr[5]^ghr[6]^ghr[7], t2_hash};

assign t2_tag = pc[WIDTH_T2 +: TAG_WIDTH_T2] ^ ghr[WIDTH_T2 +: TAG_WIDTH_T2];

assign t2_commit_idx = commit_bus.instruction_packet.tage_info.t2_idx;
assign t2_commit_tag = commit_bus.instruction_packet.tage_info.t2_tag;

always_comb begin
    //t2_match = (t2[t2_idx].tag == t2_tag);
    t2_match = (t2_out.tag == t2_tag);
end


// ***************************************************************************************
//                                  TABLE 3 DECLARATIONS
// ***************************************************************************************

typedef struct packed {
    logic [2:0]  ctr;
    logic [TAG_WIDTH_T3-1:0]  tag;
    logic [1:0]  useful; //we use this to mark how many times we've used it. Only used really when tables are full
} t3_entry_t;

t3_entry_t t3_in, t3_out;
//t3_entry_t t3 [512];

logic [8:0] t3_idx, t3_commit_idx;
logic [TAG_WIDTH_T3-1:0] t3_tag, t3_commit_tag;

logic       t3_match, t3_commit_match;

logic [15:0] t3_hash;

assign t3_hash = pc[0+:WIDTH_T3] ^ ghr[0+:WIDTH_T3] ^ pc [31-:WIDTH_T3];
assign t3_idx = t3_hash[8:0] ^ t3_hash[15:7];

assign t3_tag = pc[WIDTH_T3 +: TAG_WIDTH_T3] ^ ghr[WIDTH_T3 +: TAG_WIDTH_T3];

assign t3_commit_idx = commit_bus.instruction_packet.tage_info.t3_idx;
assign t3_commit_tag = commit_bus.instruction_packet.tage_info.t3_tag;

always_comb begin
   // t3_match = (t3[t3_idx].tag == t3_tag);
   t3_match = (t3_out.tag == t3_tag);
end


sp_ff_array #(
    .S_INDEX(9), .WIDTH(12)
) table_1 (
    .clk0       (clk),
    .rst0       (rst),
    .csb0       ('0),
    .web0       (web_t1),
    .addr0      ((web_t1) ? t1_idx : t1_commit_idx),
    .din0       (t1_in),
    .dout0      (t1_out)
);

sp_ff_array #(
    .S_INDEX(9), .WIDTH(14)
) table_2 (
    .clk0       (clk),
    .rst0       (rst),
    .csb0       ('0),
    .web0       (web_t2),
    .addr0      ((web_t2) ? t2_idx : t2_commit_idx),
    .din0       (t2_in),
    .dout0      (t2_out)
);

sp_ff_array #(
    .S_INDEX(9), .WIDTH(16)
) table_3 (
    .clk0       (clk),
    .rst0       (rst),
    .csb0       ('0),
    .web0       (web_t3),
    .addr0      ((web_t3) ? t3_idx : t3_commit_idx),
    .din0       (t3_in),
    .dout0      (t3_out)
);
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
    web_t2 = '0;
    web_t3 = '0;
    if (commit_bus.valid && commit_bus.instruction_packet.branch) begin
        if (commit_bus.instruction_packet.tage_info.provider_id == 0) begin
            web_t1 = '1;
        end else if (commit_bus.instruction_packet.tage_info.provider_id == 1) begin
            web_t1 = '1;
            web_t2 = '1;
        end else if (commit_bus.instruction_packet.tage_info.provider_id == 2) begin
            web_t2 = '1;
            web_t3 = '1;
        end else if (commit_bus.instruction_packet.tage_info.provider_id == 3) begin
            web_t3 = '1;
        end
    end 
end 

always_ff @(posedge clk) begin
    if (rst) begin
        t1_in <= '0;
        t2_in <= '0;
        t3_in <= '0;

        for (integer i = 0; i < 1024; i++) begin
            t0[i] <= '0;
        end
    end else begin
        if (commit_bus.valid && commit_bus.instruction_packet.branch) begin
            if (commit_bus.instruction_packet.tage_info.provider_id == 0) begin //Original tag came from t0
                if (commit_bus.instruction_packet.taken_branch) begin
                    if(t0[commit_bus.instruction_packet.pc[11:2]] == 3)
                        t0[commit_bus.instruction_packet.pc[11:2]] <= 2'd3;
                    else 
                        t0[commit_bus.instruction_packet.pc[11:2]] <= t0[commit_bus.instruction_packet.pc[11:2]] + 2'd1;
                end else begin
                    if(t0[commit_bus.instruction_packet.pc[11:2]] == 0)
                        t0[commit_bus.instruction_packet.pc[11:2]] <= 2'd0;
                    else 
                        t0[commit_bus.instruction_packet.pc[11:2]] <= t0[commit_bus.instruction_packet.pc[11:2]] - 2'd1;
                end
                if (mispredicted) begin 
                    if (t1_out.useful > 0) begin
                        t1_in <= t1_out;
                        t1_in.useful <= t1_in.useful - 2'd1;
                    end else begin
                        t1_in.tag <= commit_bus.instruction_packet.tage_info.t1_tag;
                        t1_in.useful <= 2'd1;
                        if (commit_bus.instruction_packet.taken_branch)
                            t1_in.ctr <= 3'd3; //Weakly taken
                        else
                            t1_in.ctr <= 3'd2; //Weakly not taken
                    end
                end 

            end else if (commit_bus.instruction_packet.tage_info.provider_id == 1) begin //Original tag came from t1
                if (commit_bus.instruction_packet.taken_branch) begin
                    if (t1_out.ctr != 7) begin
                        t1_in.ctr <= t1_out.ctr + 3'd1;
                        if (t1_out.useful != 2'd3) 
                            t1_in.useful <= t1_out.useful + 2'd1;
                    end 
                end else begin
                    if (t1_out.ctr != 0) begin
                        t1_in.ctr <= t1_out.ctr - 3'd1;
                        if (t1_in.useful != 2'd3) 
                            t1_in.useful <= t1_out.useful + 2'd1;
                    end 
                end
                //Updated t1, now we allocate in t2.
                if (mispredicted) begin 
                    if (t2_out.useful > 0) begin
                        t2_in <= t2_out;
                        t2_in.useful <= t2_in.useful - 2'd1;
                    end else begin
                        t2_in.tag <= commit_bus.instruction_packet.tage_info.t2_tag;
                        t2_in.useful <= 2'd1;
                        if (commit_bus.instruction_packet.taken_branch)
                            t2_in.ctr <= 3'd3; //Weakly taken
                        else
                            t2_in.ctr <= 3'd2; //Weakly not taken
                    end
                end 
            end 
            else if (commit_bus.instruction_packet.tage_info.provider_id == 2) begin //Original tag came from t2
                if (commit_bus.instruction_packet.taken_branch) begin
                    if (t2_out.ctr != 7) begin
                        t2_in.ctr <= t2_out.ctr + 3'd1;
                        if (t2_out.useful != 2'd3) 
                            t2_in.useful <= t2_out.useful + 2'd1;
                    end 
                end else begin
                    if (t2_out.ctr != 0) begin
                        t2_in.ctr <= t2_out.ctr - 3'd1;
                        if (t2_in.useful != 2'd3) 
                            t2_in.useful <= t2_out.useful + 2'd1;
                    end 
                end
                //Updated t2, now we allocate in t3.
                if (mispredicted) begin 
                    if (t3_out.useful > 0) begin
                        t3_in <= t3_out;
                        t3_in.useful <= t3_in.useful - 2'd1;
                    end else begin
                        t3_in.tag<= commit_bus.instruction_packet.tage_info.t3_tag;
                        t3_in.useful <= 2'd1;
                        if (commit_bus.instruction_packet.taken_branch)
                            t3_in.ctr <= 3'd3; //Weakly taken
                        else
                            t3_in.ctr <= 3'd2; //Weakly not taken
                    end
                end
            end
            else if (commit_bus.instruction_packet.tage_info.provider_id == 3) begin //Original tag came from t3
                if (commit_bus.instruction_packet.taken_branch) begin
                    if (t3_out.ctr != 7) begin
                        t3_in.ctr <= t3_out.ctr + 3'd1;
                        if (t3_out.useful != 2'd3) 
                            t3_in.useful <= t3_out.useful + 2'd1;
                    end 
                end else begin
                    if (t3_out.ctr != 0) begin
                        t3_in.ctr <= t3_out.ctr - 3'd1;
                        if (t3_in.useful != 2'd3) 
                            t3_in.useful <= t3_out.useful + 2'd1;
                    end 
                end
            end
        end
    end
end

always_comb begin
    predicted_branch = 1'b0;
    predictor_info.provider_id = 3'd0;
    predictor_info.t1_idx = t1_idx;
    predictor_info.t1_tag = t1_tag;
    predictor_info.t2_idx = t2_idx;
    predictor_info.t2_tag = t2_tag;
    predictor_info.t3_idx = t3_idx;
    predictor_info.t3_tag = t3_tag;


    if (t3_match) begin
        predictor_info.provider_id = 3'd3; //I know this is broken but for some reason this is the highest IPC
        if (t3_out.ctr >= 3) 
            predicted_branch = 1'b1;
    end
    else if (t2_match) begin
        predictor_info.provider_id = 3'd2;
        if (t2_out.ctr >= 3) 
            predicted_branch = 1'b1;
    end
    else if (t1_match) begin
        predictor_info.provider_id = 3'd1;
        if (t1_out.ctr >= 3) 
            predicted_branch = 1'b1;
    end
    else if (t0[pc[11:2]] >= 2) begin
        predicted_branch = 1'b1;
    end 

end

endmodule : tage_predictor
