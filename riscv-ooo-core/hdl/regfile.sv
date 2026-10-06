module regfile
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,
    input   logic           rename_we, commit_we,
    input   logic   [4:0]   rs1_s, rs2_s, rename_s, commit_s, //fetch_s,// register selects
    output  regfile_entry_t rs1_v, rs2_v, commit_v_r, rename_v_r, //fetch_v_r, // 2 reads in decode, 1 in commit
    input   regfile_entry_t rename_v, commit_v_w, // 1 write in rename, 1 in commit,
    input logic branch
);

    regfile_entry_t  data [32];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (integer i = 0; i < 32; i++) begin
                data[i].renamed <= 1'd0;
                data[i].rob_addr <= 5'd0;
                data[i].value <= 32'd0;
            end
        end else begin
            
            if (rename_we && (rename_s != 5'd0)) 
                data[rename_s] <= rename_v;
            if (commit_we && (commit_s != 5'd0))
                data[commit_s] <= commit_v_w;
            if (branch) begin 
                for (integer i = 0; i < 32; i++) begin 
                    data[i].renamed <= 1'd0; // but leave values
                end
            end
        end
    end

    // always_ff @(posedge clk) begin
    //     if (rst) begin
    //         rs1_v <= '0;
    //         rs2_v <= '0;
    //     end else begin
    //         rs1_v <= (rs1_s != 5'd0) ? data[rs1_s] : '0;
    //         rs2_v <= (rs2_s != 5'd0) ? data[rs2_s] : '0;
    //     end
    // end

    always_comb begin
        if (rs1_s == '0)
            rs1_v = '0;
        else if (rs1_s == rename_s & rename_we)
            rs1_v = rename_v;
        else if (rs1_s == commit_s & commit_we)
            rs1_v = commit_v_w;
        else   
            rs1_v = data[rs1_s];
        
        if (rs2_s == '0)
            rs2_v = '0;
        else if (rs2_s == rename_s & rename_we)
            rs2_v = rename_v;
        else if (rs2_s == commit_s & commit_we)
            rs2_v = commit_v_w;
        else   
            rs2_v = data[rs2_s];

        if (commit_s == '0)
            commit_v_r = '0;
        else if (commit_s == rename_s) // don't check commit_v_w here
            commit_v_r = rename_v;
        else
            commit_v_r = data[commit_s];

        // if (fetch_s == '0) fetch_v_r = '0;
        // else fetch_v_r = data[fetch_s];

        if (rename_s == '0) rename_v_r = '0;
        else if (rename_s == commit_s) rename_v_r = commit_v_w;
        else rename_v_r = data[rename_s];

    end

endmodule : regfile