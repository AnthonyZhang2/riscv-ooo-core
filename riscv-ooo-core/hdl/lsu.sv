module lsu
import rv32i_types::*;
#(
    parameter integer DEPTH=16
)
(
    input logic clk,
    input logic rst,

    input RS_Entry rs_out,
    input logic rs_valid_loadstore,

    input cdb_t data_bus, commit_bus,

    input logic [4:0] rob_head,

    output logic full,

    //Output to cache
    output   logic   [31:0]  ufp_addr,
    output   logic   [3:0]   ufp_rmask,
    output   logic   [31:0]  ufp_wdata,
    output   logic   [3:0]   ufp_wmask,
    input    logic   [31:0]  ufp_rdata,
    input    logic           ufp_resp,
    

    //Output to CDB
    output logic [31:0] mem_out,
    output logic mem_valid,
    output logic [4:0] mem_rob_idx,
    output decode_rename_t output_packet

);


lsq_entry entries [DEPTH];

logic [4:0] head, tail;

assign full  = (head[4] != tail[4]) &&
                  (head[3:0] == tail[3:0]);

logic [4:0] rob_head_lint;
assign rob_head_lint = rob_head;



logic current_mem_exec; //Check if we've issued a memory command

logic [31:0] inst;
logic   [31:0]  i_imm;
logic   [31:0]  s_imm;
logic [31:0] immediate;
logic [1:0] mem_shift;
logic [31:0] rs1_v, rs2_v;
logic [2:0] funct3;

logic [3:0] lsq_iterator;
integer lsq_it_flat;
logic ooo_load_ready;

logic delayed_current_mem_exec;
logic [3:0] delayed_lsq_iterator; // needed when rs1 bus data comes in and changes next available mid-execution


always_ff @(posedge clk) begin // updates to entries, head, tail, current_mem_exec
    if (rst) begin
        for (integer i = 0; i < DEPTH; i++) begin
            entries[i] <= '0;
        end
        head <= '0;
        tail <= '0;
        current_mem_exec <= '0;

        delayed_current_mem_exec <= '0;
        delayed_lsq_iterator <= '0;
    end else begin
        // commit/data bus updates
        if (commit_bus.valid) begin
            for (integer i = 0; i < DEPTH; i++) begin
                if (entries[i].busy) begin 
                    if(entries[i].instruction_packet.rs1_data[4:0] == commit_bus.rob_idx) begin // See decode, rob address is put in rs1_data
                        if(entries[i].instruction_packet.rs1_ready == 1'b0) begin
                            entries[i].instruction_packet.rs1_data <= commit_bus.exec_result;
                            entries[i].instruction_packet.rs1_ready <= 1'd1; // Mark operand as ready
                        end 
                    end
                    if(entries[i].instruction_packet.rs2_data[4:0] == commit_bus.rob_idx) begin // See decode, rob address is put in rs1_data
                        if(entries[i].instruction_packet.rs2_ready == 1'b0) begin
                            entries[i].instruction_packet.rs2_data <= commit_bus.exec_result;
                            entries[i].instruction_packet.rs2_ready <= 1'd1; // Mark operand as ready
                        end 
                    end
                end
            end
        end
        if (data_bus.valid) begin
            for (integer i = 0; i < DEPTH; i++) begin
                if (entries[i].busy) begin 
                    if(entries[i].instruction_packet.rs1_data[4:0] == data_bus.rob_idx) begin // See decode, rob address is put in rs1_data
                        if(entries[i].instruction_packet.rs1_ready == 1'b0) begin
                            entries[i].instruction_packet.rs1_data <= data_bus.exec_result;
                            entries[i].instruction_packet.rs1_ready <= 1'd1; // Mark operand as ready
                        end 
                    end
                    if(entries[i].instruction_packet.rs2_data[4:0] == data_bus.rob_idx) begin // See decode, rob address is put in rs1_data
                        if(entries[i].instruction_packet.rs2_ready == 1'b0) begin
                            entries[i].instruction_packet.rs2_data <= data_bus.exec_result;
                            entries[i].instruction_packet.rs2_ready <= 1'd1; // Mark operand as ready
                        end 
                    end
                end
            end
        end

        // new instruction issued
        if (rs_valid_loadstore && !full) begin
            entries[tail[3:0]].instruction_packet <= rs_out.instruction_packet;
            entries[tail[3:0]].busy <= rs_out.busy; // should always be 1 when rs_valid_loadstore is 1
            entries[tail[3:0]].rob_address <= rs_out.rob_address;
            tail <= tail + 5'b1;
        end

        // complete instruction goes on cdb, remove from queue
        if (ufp_resp & current_mem_exec) begin
            entries[delayed_lsq_iterator] <= '0;
            if (delayed_lsq_iterator == head[3:0]) 
                head <= head + 5'b1;
            current_mem_exec <= '0;
        end

        else if (entries[head[3:0]].busy) begin
            // if (!(entries[head[3:0]].instruction_packet.instruction[5]) & entries[head[3:0]].instruction_packet.rs1_ready)
            //     current_mem_exec <= '1; // remove this one when i add ooo loads

            if (commit_bus.valid & !(commit_bus.branch) & entries[head[3:0]].rob_address == commit_bus.rob_idx + 5'b1) begin
                current_mem_exec <= '1;
            end

            else if (entries[head[3:0]].rob_address == rob_head) begin
                current_mem_exec <= '1;
            end

            // if it gets here, there is an instruction at the head but not at rob head, may or may not be ready
                // if ooo_load_ready: current_mem_exec <= '1
            else if (ooo_load_ready) begin 
                current_mem_exec <= '1;
            end 
        end

        else if (head != tail) begin // head entry was issued OOO, so increment head if not empty
            head <= head + 5'b1;
        end


        delayed_current_mem_exec <= current_mem_exec;
        if (current_mem_exec & !delayed_current_mem_exec) delayed_lsq_iterator <= lsq_iterator;
    end
end

logic test_iterator;
assign test_iterator = current_mem_exec & (lsq_iterator != head[3:0]);



always_comb begin // split LSQ stuff
    for (lsq_it_flat = 0; lsq_it_flat < 16; lsq_it_flat++) begin // change upper bound to tail[3:0]
        ooo_load_ready = '0;
        // if not busy: continue
        if (4'(unsigned'(lsq_it_flat)) + head[3:0] == tail[3:0]) break;
        if (entries[4'(unsigned'(lsq_it_flat)) + head[3:0]].busy) begin
        // if store: stop, ooo_load_ready low
            if (entries[4'(unsigned'(lsq_it_flat)) + head[3:0]].instruction_packet.instruction[5])
                break;
            // if load:
                // if not ready: continue
            if (entries[4'(unsigned'(lsq_it_flat)) + head[3:0]].instruction_packet.rs1_ready) begin 
                ooo_load_ready = '1;
                break;
            end
        end
            // if ready: stop, ooo_load_ready high

    end

    lsq_iterator = 4'(unsigned'(lsq_it_flat)) + head[3:0]; 

end

always_comb begin
    inst = (delayed_current_mem_exec) ? entries[delayed_lsq_iterator].instruction_packet.instruction : entries[lsq_iterator].instruction_packet.instruction;
    rs1_v = (delayed_current_mem_exec) ? entries[delayed_lsq_iterator].instruction_packet.rs1_data : entries[lsq_iterator].instruction_packet.rs1_data;
    rs2_v = (delayed_current_mem_exec) ? entries[delayed_lsq_iterator].instruction_packet.rs2_data : entries[lsq_iterator].instruction_packet.rs2_data;
    s_imm  = {{21{inst[31]}}, inst[30:25], inst[11:7]};
    i_imm  = {{21{inst[31]}}, inst[30:20]};
    immediate = (inst[5]) ? s_imm : i_imm;
    mem_shift = immediate[1:0] + rs1_v[1:0];
    funct3 = inst[14:12];

    if (current_mem_exec) begin // set cache signals
        ufp_addr = rs1_v + immediate;
        ufp_addr[1:0] = 2'b0;

        ufp_wdata = '0;

        if (inst[5]) begin
            ufp_rmask = '0;
            unique case (funct3)
                store_f3_sb: ufp_wmask = 4'b0001 << mem_shift;
                store_f3_sh: ufp_wmask = 4'b0011 << mem_shift;
                store_f3_sw: ufp_wmask = 4'b1111;
                default    : ufp_wmask = 'x;
            endcase

            unique case (funct3)
                store_f3_sb: ufp_wdata[8 *mem_shift     +: 8 ] = rs2_v[7 :0];
                store_f3_sh: ufp_wdata[16*mem_shift[1]  +: 16] = rs2_v[15:0];
                store_f3_sw: ufp_wdata = rs2_v;
                default    : ufp_wdata = 'x;
            endcase
        end else begin
            ufp_wmask = '0;
            unique case (funct3)
                load_f3_lb, load_f3_lbu: ufp_rmask = 4'b0001 << mem_shift;
                load_f3_lh, load_f3_lhu: ufp_rmask = 4'b0011 << mem_shift;
                load_f3_lw             : ufp_rmask = 4'b1111;
                default                : ufp_rmask = 'x;
            endcase
        end

        if (ufp_addr < 32'haaaaa000) begin
            ufp_rmask = '0;
            ufp_wmask = '0;
        end

    end else begin 
        ufp_addr = '0;
        ufp_wdata = '0;
        ufp_rmask = '0;
        ufp_wmask = '0;
    end

    if (ufp_resp & current_mem_exec) begin // set cdb signals
        output_packet = entries[delayed_lsq_iterator].instruction_packet;
        mem_valid = 1'b1;
        mem_rob_idx = entries[delayed_lsq_iterator].rob_address;
        mem_out = '0;
        if (|ufp_rmask) begin
            unique case (funct3)
                load_f3_lb : mem_out = {{24{ufp_rdata[7 +8 * mem_shift[1:0]]}}, ufp_rdata[8 * mem_shift[1:0] +: 8 ]};
                load_f3_lbu: mem_out = {{24{1'b0}}                          , ufp_rdata[8 * mem_shift[1:0] +: 8 ]};
                load_f3_lh : mem_out = {{16{ufp_rdata[15+16* mem_shift[1]  ]}}, ufp_rdata[16* mem_shift[1]   +: 16]};
                load_f3_lhu: mem_out = {{16{1'b0}}                          , ufp_rdata[16* mem_shift[1]   +: 16]};
                load_f3_lw : mem_out = ufp_rdata;
                default    : mem_out = 'x;
            endcase
        end

        output_packet.mem_addr = {ufp_addr[31:2], mem_shift};
        output_packet.mem_rmask = ufp_rmask;
        output_packet.mem_wmask = ufp_wmask;
        output_packet.mem_wdata = ufp_wdata;
        output_packet.mem_rdata = ufp_rdata;
    end else begin 
        output_packet = '0;
        mem_valid = '0;
        mem_out = '0;
        mem_rob_idx = '0;
    end
end


endmodule : lsu