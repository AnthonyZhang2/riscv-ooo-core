module cpu
import rv32i_types::*;
(
    input   logic               clk,
    input   logic               rst,

    output  logic   [31:0]      bmem_addr,
    output  logic               bmem_read,
    output  logic               bmem_write,
    output  logic   [63:0]      bmem_wdata,
    input   logic               bmem_ready,

    input   logic   [31:0]      bmem_raddr,
    input   logic   [63:0]      bmem_rdata,
    input   logic               bmem_rvalid
);


logic   [31:0]      ufp_addr;     // signals from cache
logic   [3:0]       ufp_write;
logic   [255:0]      ufp_rdata;
logic               ufp_resp;

 
logic   [31:0]      dfp_addr;     // signals from cache
logic               dfp_read;
logic               dfp_write;
logic   [255:0]     dfp_rdata;
logic   [255:0]     dfp_wdata;
logic               dfp_resp;

logic   [31:0]      d_dfp_addr;     // signals from cache
logic               d_dfp_read;
logic               d_dfp_write;
logic   [255:0]     d_dfp_rdata;
logic   [255:0]     d_dfp_wdata;
logic               d_dfp_resp;
logic handling_dcache_req, handling_icache_req;

logic [31:0] load_ufp_addr, d_pre_addr;
logic [3:0] load_wmask, load_rmask, d_pre_wmask, d_pre_rmask;
logic [31:0] load_wdata, load_rdata, d_pre_wdata, d_pre_rdata;
logic load_resp, d_pre_resp;
logic mem_complete_temp;

logic [31:0] i_pre_addr;
logic i_pre_rmask;
logic [255:0] i_pre_rdata;
logic i_pre_resp;


cacheline_adapter cacheline(
    .clk        (clk),
    .rst        (rst),

    .i_dfp_addr   (dfp_addr),
    .i_dfp_read   (dfp_read),
    .i_dfp_write  (dfp_write),
    .i_dfp_rdata  (dfp_rdata),
    .i_dfp_wdata  (dfp_wdata),
    .i_dfp_resp   (dfp_resp),

    .d_dfp_addr   (d_dfp_addr),
    .d_dfp_read   (d_dfp_read),
    .d_dfp_write  (d_dfp_write),
    .d_dfp_rdata  (d_dfp_rdata),
    .d_dfp_wdata  (d_dfp_wdata),
    .d_dfp_resp   (d_dfp_resp),

    .bmem_addr   (bmem_addr),
    .bmem_read   (bmem_read),
    .bmem_write  (bmem_write),
    .bmem_rdata  (bmem_rdata),
    .bmem_wdata  (bmem_wdata),
    .bmem_ready  (bmem_ready),
    .bmem_raddr  (bmem_raddr),
    .bmem_rvalid (bmem_rvalid),

    .handling_dcache_req(handling_dcache_req),
    .handling_icache_req(handling_icache_req)
);

logic fetch_backpressure;

logic icache_rmask;

logic full, empty, branch;

iqueue_entry_t fetch_out;
decode_rename_t decode_out, decode_out_reg;
iqueue_entry_t rd_data;

logic [4:0] rs1_s, rs2_s, rename_s, commit_s, fetch_s;
regfile_entry_t rs1_regfile_data, rs2_regfile_data, rename_v, commit_v_r, commit_v_w, rename_v_r, fetch_v_r;
cdb_t cdb, commit_bus;
logic rename_we, commit_we;

logic [4:0] rob_tail_idx;
logic [4:0] rob_head;
logic rob_input_valid, rob_full;

//Reservation Stations signals
RS_Entry rs_out;
logic rs_valid_alu, rs_valid_muldiv;
logic rs_full_alu, rs_full_muldiv;
logic alu_exec_valid, muldiv_exec_valid;
decode_rename_t alu_res_out, muldiv_res_out, muldiv_exec_out;
logic [4:0] alu_out_rob_address, muldiv_out_rob_address;

//alu signals
logic [31:0] alu_out;
logic alu_valid;

//muldiv signals
logic inst_hold, inst_start;
logic [31:0] muldiv_out;
logic muldiv_complete;

//mem signals
logic rs_valid_loadstore;
logic rs_full_loadstore;
logic [31:0] mem_out;
logic mem_valid;
logic [4:0] mem_rob_idx;
decode_rename_t mem_packet;

//cdb signals
logic alu_cdb_done;
logic muldiv_cdb_done;
logic delayed_muldiv_valid;

logic dequeue;


fetch fetch_module(
    .clk(clk),
    .rst(rst),
    .icache_rdata(ufp_rdata),
    .icache_resp(ufp_resp),
    .fetch_backpressure(full),

    .commit_bus(commit_bus),
    //.branch(branch),

    .icache_rmask(icache_rmask),
    // .fetch_v_r(fetch_v_r),
    // .fetch_s(fetch_s),
    .fetch_out(fetch_out)
);

decode decode_module( // decodes instruction, reads register file for operands
    .rst(rst || commit_bus.branch),
    .decode_in(rd_data),
    .rs1_addr(rs1_s), // connect these four signals to regfile read ports
    .rs2_addr(rs2_s),
    .rs1_regfile_data(rs1_regfile_data),
    .rs2_regfile_data(rs2_regfile_data),
    .cdb(cdb),
    .commit_bus(commit_bus),
    .decode_out(decode_out) // goes into decoded instruction register used by rename/dispatch
);

always_ff @(posedge clk) begin
    if (rst | (dequeue & !decode_out.valid) | commit_bus.branch)
        decode_out_reg <= '0;
    else if (dequeue)
        decode_out_reg <= decode_out;
    else begin // update with cdb, commit bus values
        if (decode_out_reg.use_rs1 & !(decode_out_reg.rs1_ready) & cdb.valid & cdb.rob_idx == decode_out_reg.rs1_data[4:0]) begin // check CDB for register data, waiting registers have rob_addr in data[4:0] (see decode)
            decode_out_reg.rs1_ready <= '1;
            decode_out_reg.rs1_data <= cdb.exec_result;
        end else if (decode_out_reg.use_rs1 & !(decode_out_reg.rs1_ready) & commit_bus.valid & commit_bus.rob_idx == decode_out_reg.rs1_data[4:0]) begin // check CDB for register data, waiting registers have rob_addr in data[4:0] (see decode)
            decode_out_reg.rs1_ready <= '1;
            decode_out_reg.rs1_data <= commit_bus.exec_result;
        end
        if (decode_out_reg.use_rs2 & !(decode_out_reg.rs2_ready) & cdb.valid & cdb.rob_idx == decode_out_reg.rs2_data[4:0]) begin
            decode_out_reg.rs2_ready <= '1;
            decode_out_reg.rs2_data <= cdb.exec_result;
        end else if (decode_out_reg.use_rs2 & !(decode_out_reg.rs2_ready) & commit_bus.valid & commit_bus.rob_idx == decode_out_reg.rs2_data[4:0]) begin
            decode_out_reg.rs2_ready <= '1;
            decode_out_reg.rs2_data <= commit_bus.exec_result;
        end
    end
end



logic test_alu_ready;
always_ff @(posedge clk) begin
    if (rst) 
        test_alu_ready <= '0;
    else
        test_alu_ready <= !test_alu_ready;
end

regfile regfile (
    .clk(clk),
    .rst(rst),
    .rename_we(rename_we),
    .commit_we(commit_we),
    .rs1_s(rs1_s),
    .rs2_s(rs2_s),
    .rename_s(rename_s), 
    .commit_s(commit_s), 
    .rs1_v(rs1_regfile_data), 
    .rs2_v(rs2_regfile_data), 
    .commit_v_r(commit_v_r), 
    .rename_v(rename_v), 
    .commit_v_w(commit_v_w),
    .rename_v_r(rename_v_r),
    // .fetch_v_r(fetch_v_r),
    // .fetch_s(fetch_s),
    .branch(commit_bus.branch)
);

rename_station rename (
    .dec_in(decode_out_reg),
    .dec_ready(dequeue),
    .rs_out(rs_out),
    .rs_valid_alu(rs_valid_alu),
    .rs_valid_muldiv(rs_valid_muldiv),
    .rs_valid_loadstore(rs_valid_loadstore),
    .rs_full_alu(rs_full_alu),
    .rs_full_muldiv(rs_full_muldiv),
    .rs_full_loadstore(rs_full_loadstore),
    .rob_input_valid(rob_input_valid),
    .rob_full(rob_full),
    .rob_tail_idx(rob_tail_idx),
    .cdb(cdb),
    .commit_bus(commit_bus),
    .rename_s(rename_s),
    .rename_v(rename_v),
    .rename_we(rename_we),
    .rename_v_r(rename_v_r)
);

FIFO #(.DATA_WIDTH($bits(iqueue_entry_t)), .DEPTH(8)) instruction_queue(
    .clk(clk),
    .rst(rst || commit_bus.branch),
    .enqueue(fetch_out.valid),
    .wr_data(fetch_out),
    .dequeue(dequeue),
    .rd_data(rd_data),
    .full(full),
    .empty(empty)
);

prefetcher #(.DATA_WIDTH(256), .MASK_WIDTH(1)) instruction_prefetcher (
    .clk (clk),
    .rst (rst),
    .fetch_addr(fetch_out.pc),
    .fetch_rmask(icache_rmask),
    .fetch_wmask('0),
    .fetch_rdata(ufp_rdata),
    .fetch_wdata('0),
    .fetch_resp(ufp_resp),
    
    .cache_addr(i_pre_addr),
    .cache_rmask(i_pre_rmask),
    .cache_wmask(),
    .cache_rdata(i_pre_rdata),
    .cache_wdata(),
    .cache_resp(i_pre_resp),
    
    .on(1'b1),
    .prefetch_on_access(1'b0)
);

icache #(.SETS(64), .WAYS(2)) icache(
    .clk        (clk),
    .rst        (rst),
    
    .ufp_addr   (i_pre_addr),
    .ufp_rmask  (i_pre_rmask),
    .ufp_rdata  (i_pre_rdata),
    .ufp_resp   (i_pre_resp),

    .dfp_addr   (dfp_addr),
    .dfp_read   (dfp_read),
    .dfp_write  (dfp_write),
    .dfp_rdata  (dfp_rdata),
    .dfp_wdata  (dfp_wdata),
    .dfp_resp   (dfp_resp),

    .adapter_handling(handling_icache_req)
);

prefetcher #(.DATA_WIDTH(32), .MASK_WIDTH(4)) data_prefetcher (
    .clk (clk),
    .rst (rst),
    .fetch_addr(load_ufp_addr),
    .fetch_rmask(load_rmask),
    .fetch_wmask(load_wmask),
    .fetch_rdata(load_rdata),
    .fetch_wdata(load_wdata),
    .fetch_resp(load_resp),
    
    .cache_addr(d_pre_addr),
    .cache_rmask(d_pre_rmask),
    .cache_wmask(d_pre_wmask),
    .cache_rdata(d_pre_rdata),
    .cache_wdata(d_pre_wdata),
    .cache_resp(d_pre_resp),
    
    .on(1'b1),
    .prefetch_on_access(1'b0)
);

dcache #(.SETS(16), .WAYS(4)) dcache(
    .clk        (clk),
    .rst        (rst),
    
    .ufp_addr   (d_pre_addr),
    .ufp_rmask  (d_pre_rmask),
    .ufp_rdata  (d_pre_rdata),
    .ufp_resp   (d_pre_resp),
    .ufp_wmask  (d_pre_wmask),
    .ufp_wdata  (d_pre_wdata),

    .dfp_addr   (d_dfp_addr),
    .dfp_read   (d_dfp_read),
    .dfp_write  (d_dfp_write),
    .dfp_rdata  (d_dfp_rdata),
    .dfp_wdata  (d_dfp_wdata),
    .dfp_resp   (d_dfp_resp),

    .adapter_handling(handling_dcache_req)
);


reorder reorder (
    .clk(clk),
    .rst(rst),
    .input_valid(rob_input_valid),
    .data_bus(cdb),
    // .flush('0),
    .commit_dest(commit_s),
    .commit_v_r(commit_v_r),
    .commit_v_w(commit_v_w),
    .commit_valid(commit_we),
    //.branch_taken(branch),
    .full(rob_full),
    .tail_out(rob_tail_idx),
    .commit_bus(commit_bus),
    .head_out(rob_head)
);

logic valid_inst;
logic [4:0] temp_muldiv_rob_addr;

always_ff @(posedge clk) begin
    if (rst) begin
        valid_inst <= 1'b0;
    end else begin
        if(muldiv_exec_valid && !valid_inst) begin
            valid_inst <= 1'b1;
        end else if (muldiv_complete) begin
            valid_inst <= 1'b0;
        end
    end
end

reservation alu_reservation (
    .clk(clk),
    .rst(rst || commit_bus.branch),

    .new_rs_entry(rs_out),
    .valid_input(rs_valid_alu),

    .exec_ready(!(mem_valid | (muldiv_complete & valid_inst) | delayed_muldiv_valid)), // alu only stalled when muldiv result is on cdb
    .data_bus(cdb),
    .commit_bus(commit_bus),

    .full(rs_full_alu),
    .exec_valid(alu_exec_valid),

    .out_rob_address(alu_out_rob_address),
    .output_packet(alu_res_out)
);



reservation muldiv_reservation (
    .clk(clk),
    .rst(rst || commit_bus.branch),

    .new_rs_entry(rs_out),
    .valid_input(rs_valid_muldiv),

    .exec_ready(muldiv_complete & !mem_valid),
    .data_bus(cdb),
    .commit_bus(commit_bus),

    .full(rs_full_muldiv),
    .exec_valid(muldiv_exec_valid),

    .out_rob_address(temp_muldiv_rob_addr),
    .output_packet(muldiv_res_out)
);


lsu load_store_unit (
    .clk(clk),
    .rst(rst || commit_bus.branch),
    
    .rs_out(rs_out),
    .rs_valid_loadstore(rs_valid_loadstore),

    .commit_bus(commit_bus),
    .data_bus(cdb),
    .rob_head(rob_head),

    .full(rs_full_loadstore),

    .ufp_addr(load_ufp_addr),
    .ufp_rmask(load_rmask),
    .ufp_wdata(load_wdata),
    .ufp_wmask(load_wmask),
    .ufp_rdata(load_rdata),
    .ufp_resp(load_resp),

    .mem_out(mem_out),
    .mem_valid(mem_valid),
    .mem_rob_idx(mem_rob_idx),
    .output_packet(mem_packet)
);


alu alu_unit (
    .inst_packet(alu_res_out),
    
    .aluout(alu_out),
    .branch(branch),
    .valid(alu_valid)
);



muldiv_unit multiply_division_unit (
    .clk(clk),
    .rst(rst || commit_bus.branch),
    .inst_hold(inst_hold),
    .inst_start(muldiv_exec_valid),
    .input_packet(muldiv_res_out),

    .output_packet(muldiv_exec_out),
    .complete_inst(muldiv_complete),
    .data_out(muldiv_out),
    .rob_addr_in(temp_muldiv_rob_addr),
    .rob_addr_out(muldiv_out_rob_address)
);



cdb common_data_bus (
    .clk(clk),
    .rst(rst || commit_bus.branch),

    .alu_out(alu_out), 
    .alu_valid(alu_valid && alu_exec_valid), 
    .alu_rob_idx(alu_out_rob_address),

    .muldiv_out(muldiv_out),
    .muldiv_valid(muldiv_complete && valid_inst && muldiv_exec_out.valid),
    .muldiv_rob_idx(muldiv_out_rob_address),

    .mem_out(mem_out),
    .mem_valid(mem_valid),
    .mem_rob_idx(mem_rob_idx),

    .branch(branch),

    .cdb_out(cdb),

    .stall_muldiv(inst_hold),
    .alu_complete(alu_cdb_done),
    .muldiv_complete(muldiv_cdb_done),
    .mem_complete(mem_complete_temp),

    .alu_packet(alu_res_out),
    .muldiv_packet(muldiv_exec_out),
    .mem_packet(mem_packet),
    .delayed_muldiv_valid(delayed_muldiv_valid)
);
endmodule : cpu
