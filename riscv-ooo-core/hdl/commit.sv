module commit 
import rv32i_types::*;
(
    input logic clk,
    input logic rst,

    input logic [4:0] commit_dest,
    input instr_variants commit_type,
    input logic [31:0] commit_result,
    input logic commit_valid,
    input logic branch_taken, 
    input logic [63:0] commit_order,

    output logic [31:0] rd_v,
    output logic regf_we,
    output logic [4:0] rd_s,

    output logic [31:0] mem_addr,
    output logic mem_write,
    output logic [63:0] commit_out
);



// always_ff @(posedge clk) begin
//     if (rst) begin
//         rd_v <= 32'b0;
//         regf_we <= 1'b0;
//         rd_s <= 5'd0;

//         mem_addr <= 32'd0;
//         mem_write <= 1'd0;
//         commit_out <= 64'b0;
//     end else begin
//         if (commit_valid) begin
//             commit_out <= commit_order;
//             if (commit_type == i_type || commit_type == r_type) begin
//                 rd_v <= commit_result; 
//                 regf_we <= 1'b1;      
//                 rd_s <= commit_dest;  
//             end else if (commit_type == s_type) begin
//                 // IMPLEMENT LATER
//                 mem_write <= 1'b1;
//             end
//         end else begin
//             rd_v <= 32'b0;
//             regf_we <= 1'b0;
//             rd_s <= 5'd0;

//             mem_addr <= 32'd0;
//             mem_write <= 1'd0;
//             commit_out <= commit_out;
//         end
//     end
// end

logic [63:0] commit_reg;

always_comb begin
    if (rst) begin
        rd_v = 32'b0;
        regf_we = 1'b0;
        rd_s = 5'd0;

        mem_addr = 32'd0;
        mem_write = 1'd0;
        commit_out = 64'b0;
    end else begin
        rd_v = 32'b0;
        regf_we = 1'b0;
        rd_s = 5'd0;

        mem_addr = 32'd0;
        mem_write = 1'd0;
        commit_out = 64'b0;
        if (commit_valid) begin
            commit_out = commit_order;
            if (commit_type == i_type || commit_type == r_type) begin
                rd_v = commit_result; 
                regf_we = 1'b1;      
                rd_s = commit_dest;  
            end else if (commit_type == s_type) begin
                // IMPLEMENT LATER
                mem_write = 1'b1;
            end
        end else begin
            rd_v = 32'b0;
            regf_we = 1'b0;
            rd_s = 5'd0;

            mem_addr = 32'd0;
            mem_write = 1'd0;
            commit_out = commit_reg;
        end
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        commit_reg <= 64'd0;
    end else begin
        if (commit_valid) begin
            commit_reg <= commit_order;
        end else begin
            commit_reg <= commit_reg;
        end
    end
end

endmodule : commit