module decode 
import rv32i_types::*;
(
    input logic rst,

    input iqueue_entry_t decode_in,

    output logic [4:0] rs1_addr,
    output logic [4:0] rs2_addr,
    input regfile_entry_t rs1_regfile_data,
    input regfile_entry_t rs2_regfile_data,
    
    input cdb_t cdb, commit_bus,
    output decode_rename_t decode_out
);

logic [31:0] inst;
logic [4:0] rd_addr;
logic [2:0] aluop;
logic [2:0] cmpop;
logic [1:0] functional_unit;
logic comparator;
logic use_rs1;
logic rs1_ready;
logic rs2_ready;
logic use_rs2;
logic branch;
logic taken_branch;
logic [1:0] jal;
logic [31:0] rs1_data;
logic [31:0] rs2_data;

logic [2:0] funct3;
logic [6:0] funct7;
logic [6:0] opcode;
logic   [31:0]  i_imm;
logic   [31:0]  s_imm;
logic   [31:0]  b_imm;
logic   [31:0]  u_imm;
logic   [31:0]  j_imm;

logic [3:0] mem_rmask, mem_wmask;
logic [31:0] mem_addr, mem_rdata, mem_wdata;

logic is_store;


always_comb begin
    rs1_data = '0;
    rs2_data = '0;
    rs1_ready = '1;
    rs2_ready = '1;
    use_rs1 = '0;
    use_rs2 = '0;
    branch = '0;
    jal = '0;
    inst = decode_in.instruction;
    rs1_addr = inst[19:15];
    rs2_addr = inst[24:20];
    rd_addr = inst[11:7];
    is_store = '0;
    taken_branch = '0;
    
    funct3 = inst[14:12];
    funct7 = inst[31:25];
    opcode = inst[6:0];
    i_imm  = {{21{inst[31]}}, inst[30:20]};
    s_imm  = {{21{inst[31]}}, inst[30:25], inst[11:7]};
    b_imm  = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    u_imm  = {inst[31:12], 12'h000};
    j_imm  = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
    aluop = alu_op_add;

    functional_unit = fu_alu; // set this in decode, then look at it for dispatch in rename
    comparator = '0; // for now, this is just 1 for slt instructions, also can be used for branching if needed
    cmpop = '0; // same

    mem_rmask = '0; // need rs1 data for masks
    mem_wmask = '0;
    mem_addr = '0;
    mem_rdata = '0;
    mem_wdata = '0;

    unique case (opcode)
        op_b_auipc: begin
            rs1_data = decode_in.pc;
            rs2_data = u_imm;
        end
        op_b_lui: begin
            rs1_data = '0;
            rs2_data = u_imm;
        end
        op_b_reg: begin
            use_rs1 = '1;
            use_rs2 = '1;
            unique case (funct3)
                arith_f3_slt: begin
                    comparator = '1;
                    cmpop = branch_f3_blt;
                end
                arith_f3_sltu: begin
                    comparator = '1;
                    cmpop = branch_f3_bltu;
                end
                arith_f3_sr: begin
                    if (funct7[5]) aluop = alu_op_sra;
                    else aluop = alu_op_srl;
                end
                arith_f3_add: begin
                    if (funct7[5]) aluop = alu_op_sub;
                    else aluop = alu_op_add;
                end
                default: begin
                    aluop = funct3;
                end
            endcase
            if (funct7 == muldiv) begin // mul, div, rem instructions just use aluop differently, and different value for functional unit
                aluop = funct3;
                functional_unit = fu_muldiv;
            end
        end
        op_b_imm: begin
            use_rs1 = '1;
            rs2_data = i_imm;
            unique case (funct3)
                arith_f3_slt: begin
                    comparator = '1;
                    cmpop = branch_f3_blt;
                end
                arith_f3_sltu: begin
                    comparator = '1;
                    cmpop = branch_f3_bltu;
                end
                arith_f3_sr: begin
                    if (funct7[5]) aluop = alu_op_sra;
                    else aluop = alu_op_srl;
                end
                default: begin
                    aluop = funct3;
                end
            endcase
        end
        op_b_load: begin
            use_rs1 = '1;
            rs2_data = '0;
            // mem_addr = i_imm; // need to add rs1 later, rs1 might not be ready here

            is_store = 1'b0;

            // can't set rmask yet, need rs1 data
            functional_unit = fu_mem;
        end
        op_b_store: begin
            use_rs1 = '1; // need both register values for stores
            use_rs2 = '1;
            rd_addr = '0; // make sure writeback doesn't affect anything by writing to x0
            // mem_addr = s_imm; // need to add rs1 later, might not be ready here
            // can't set wmask yet, need rs1 data
            is_store = 1'b1;

            functional_unit = fu_mem;
        end
        op_b_br: begin
            use_rs1 = '1;
            use_rs2 = '1;
            branch = 1'b1;
            rd_addr = '0;
        end
        op_b_jal: begin 
            branch = 1'b1;
            jal = 2'b01;
            rs2_data = j_imm;
        end
        op_b_jalr: begin 
            use_rs1 = '1;
            branch = 1'b1;
            jal = 2'b10;
            rs2_data = i_imm;
        end
        default: begin
        end
    endcase

    if (use_rs1) begin
        if (!(rs1_regfile_data.renamed))
            rs1_data = rs1_regfile_data.value;
        else begin
            if (cdb.valid & cdb.rob_idx == rs1_regfile_data.rob_addr)
                rs1_data = cdb.exec_result;
            else if (commit_bus.valid & commit_bus.rob_idx == rs1_regfile_data.rob_addr)
                rs1_data = commit_bus.exec_result;
            else begin
                rs1_data = {27'b0, rs1_regfile_data.rob_addr}; 
                rs1_ready = '0;
            end
        end
    end else
        rs1_addr = '0;

    if (use_rs2) begin
        if (!(rs2_regfile_data.renamed))
            rs2_data = rs2_regfile_data.value;
        else begin
            if (cdb.valid & cdb.rob_idx == rs2_regfile_data.rob_addr)
                rs2_data = cdb.exec_result;
            else if (commit_bus.valid & commit_bus.rob_idx == rs2_regfile_data.rob_addr)
                rs2_data = commit_bus.exec_result;
            else begin
                rs2_data = {27'b0, rs2_regfile_data.rob_addr};
                rs2_ready = '0;
            end
        end
    end else
        rs2_addr = '0;

end

always_comb begin
    decode_out.instruction = decode_in.instruction;
    decode_out.pc = decode_in.pc;
    decode_out.pc_next = decode_in.pc_next;
    decode_out.order = decode_in.order;
    decode_out.rs1_addr = rs1_addr;
    decode_out.rs2_addr = rs2_addr;
    decode_out.rd_addr = rd_addr;
    decode_out.valid = decode_in.valid & !rst;
    decode_out.aluop = aluop;
    decode_out.cmpop = cmpop;
    decode_out.branch = branch;
    decode_out.jal = jal;
    decode_out.is_store = is_store;
    decode_out.use_rs1 = use_rs1;
    decode_out.use_rs2 = use_rs2;
    decode_out.rs1_ready = rs1_ready;
    decode_out.rs2_ready = rs2_ready;
    decode_out.rs1_data = rs1_data;
    decode_out.rs2_data = rs2_data;
    decode_out.functional_unit = functional_unit;
    decode_out.comparator = comparator;
    decode_out.mem_rmask = mem_rmask; // these are set in lsu
    decode_out.mem_wmask = mem_wmask;
    decode_out.mem_addr = mem_addr;
    decode_out.mem_rdata = mem_rdata;
    decode_out.mem_wdata = mem_wdata;
    decode_out.predicted_branch = decode_in.predicted_branch;
    decode_out.taken_branch = taken_branch;
    decode_out.tage_info = decode_in.tage_info;
end

endmodule : decode