/////////////////////////////////////////////////////////////
// Maybe merge what is in mp_verif/pkg/types.sv over here? //
/////////////////////////////////////////////////////////////

package rv32i_types;

    typedef enum logic {
        rs1_out = 1'b0,
        pc_out  = 1'b1
    } alu_m1_sel_t;

    

    // more mux def here

    typedef enum logic [6:0] {
        op_b_lui       = 7'b0110111, // load upper immediate (U type)
        op_b_auipc     = 7'b0010111, // add upper immediate PC (U type)
        op_b_jal       = 7'b1101111, // jump and link (J type)
        op_b_jalr      = 7'b1100111, // jump and link register (I type)
        op_b_br        = 7'b1100011, // branch (B type)
        op_b_load      = 7'b0000011, // load (I type)
        op_b_store     = 7'b0100011, // store (S type)
        op_b_imm       = 7'b0010011, // arith ops with register/immediate operands (I type)
        op_b_reg       = 7'b0110011  // arith ops with register operands (R type)
    } rv32i_opcode;

    typedef enum logic [2:0] {
        arith_f3_add   = 3'b000, // check logic 30 for sub if op_reg op
        arith_f3_sll   = 3'b001,
        arith_f3_slt   = 3'b010,
        arith_f3_sltu  = 3'b011,
        arith_f3_xor   = 3'b100,
        arith_f3_sr    = 3'b101, // check logic 30 for logical/arithmetic
        arith_f3_or    = 3'b110,
        arith_f3_and   = 3'b111
    } arith_f3_t;

    typedef enum logic [2:0] {
        muldiv_f3_mul    = 3'b000,
        muldiv_f3_mulh   = 3'b001,
        muldiv_f3_mulhsu = 3'b010,
        muldiv_f3_mulhu  = 3'b011,
        muldiv_f3_div    = 3'b100,
        muldiv_f3_divu   = 3'b101,
        muldiv_f3_rem    = 3'b110,
        muldiv_f3_remu   = 3'b111
    } muldiv_f3_t;

    typedef enum logic [2:0] {
        arith_f3_addi   = 3'b000, // check logic 30 for sub if op_reg op
        arith_f3_slti   = 3'b010,
        arith_f3_sltiu  = 3'b011,
        arith_f3_xori   = 3'b100,
        arith_f3_ori    = 3'b110,
        arith_f3_andi   = 3'b111
    } arith_i_f3_t;

    typedef enum logic [2:0] {
        r_type     = 3'b000,
        i_type     = 3'b001,
        s_type     = 3'b010,
        b_type     = 3'b100,
        u_type     = 3'b101,
        j_type     = 3'b110,
        invalid    = 3'b111
    } instr_variants;

    typedef enum logic [2:0] {
        load_f3_lb     = 3'b000,
        load_f3_lh     = 3'b001,
        load_f3_lw     = 3'b010,
        load_f3_lbu    = 3'b100,
        load_f3_lhu    = 3'b101
    } load_f3_t;

    typedef enum logic [2:0] {
        store_f3_sb    = 3'b000,
        store_f3_sh    = 3'b001,
        store_f3_sw    = 3'b010
    } store_f3_t;

    typedef enum logic [2:0] {
        branch_f3_beq  = 3'b000,
        branch_f3_bne  = 3'b001,
        branch_f3_blt  = 3'b100,
        branch_f3_bge  = 3'b101,
        branch_f3_bltu = 3'b110,
        branch_f3_bgeu = 3'b111
    } branch_f3_t;

    typedef enum logic [2:0] {
        alu_op_add     = 3'b000,
        alu_op_sll     = 3'b001,
        alu_op_sra     = 3'b010,
        alu_op_sub     = 3'b011,
        alu_op_xor     = 3'b100,
        alu_op_srl     = 3'b101,
        alu_op_or      = 3'b110,
        alu_op_and     = 3'b111
    } alu_ops;

    typedef enum logic [6:0] {
        base           = 7'b0000000,
        variant        = 7'b0100000,
        muldiv         = 7'b0000001
    } funct7_t;

    typedef enum logic [2:0] {
        funct3base         = 3'b000,
        variant1           = 3'b001,
        variant2           = 3'b010,
        variant3           = 3'b011,
        variant4           = 3'b100,
        variant5           = 3'b101,
        variant6           = 3'b110,
        variant7           = 3'b111
    } funct3_t;

    typedef enum logic [1:0] {
        fu_alu = 2'b0,
        fu_muldiv = 2'b01,
        fu_mem = 2'b10,
        fu_control = 2'b11
    } functional_unit_t;


    typedef union packed {
        logic [31:0] word;

        struct packed {
            logic [11:0] i_imm;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } i_type;

        struct packed {
            logic [6:0]  funct7;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } r_type;

        struct packed {
            logic [31:12] imm_u_top;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } u_type;

        struct packed {
            logic [11:5] imm_s_top;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  imm_s_bot;
            rv32i_opcode opcode;
        } s_type;

        struct packed {
            logic        imm_b_12;
            logic [10:5] imm_b_top;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:1]  imm_b_bot;
            logic        imm_b_11;
            rv32i_opcode opcode;
        } b_type;

        struct packed {
            logic [31:12] imm;
            logic [4:0]   rd;
            rv32i_opcode  opcode;
        } j_type;

    } instr_t;

    typedef struct packed {
        logic [2:0] provider_id;
        logic [9:0] t1_idx;
        logic [6:0] t1_tag;
        logic [8:0] t2_idx;
        logic [8:0] t2_tag;
        logic [8:0] t3_idx;
        logic [10:0] t3_tag;
    } tage_info;

    typedef struct packed {
        logic [31:0]  pc;
        logic [31:0]  pc_next;
        logic [31:0]  instruction;
        logic [63:0]  order;
        logic predicted_branch;
        tage_info tage_info;
        logic valid;
    } iqueue_entry_t;

    typedef struct packed {
        logic [31:0]    instruction;
        logic [31:0]    pc;
        logic [31:0]    pc_next;
        logic [4:0]     rs1_addr;
        logic [4:0]     rs2_addr;
        logic [4:0]     rd_addr;
        logic [63:0]    order;
        logic valid;
        logic [1:0] functional_unit;
        logic [2:0] aluop;
        logic [2:0] cmpop;
        logic comparator;
        logic use_rs1;
        logic rs1_ready;
        logic rs2_ready;
        logic use_rs2;
        logic predicted_branch;
        logic taken_branch;
        logic branch;
        logic is_store;
        logic [1:0] jal; // 1 = jal, 2 = jalr
        logic [31:0] rs1_data;
        logic [31:0] rs2_data;
        logic [3:0] mem_rmask;
        logic [3:0] mem_wmask;
        logic [31:0] mem_addr;
        logic [31:0] mem_rdata;
        logic [31:0] mem_wdata;
        tage_info tage_info;
    } decode_rename_t;

    typedef struct packed {
        logic renamed;
        logic [4:0] rob_addr;
        logic [31:0] value;
    } regfile_entry_t;

    typedef struct packed {
        logic               valid;        
        logic [31:0]        result; // The result
        logic               done; // Result valid
        decode_rename_t   instruction_packet;
        logic               branch;
    } rob_entry_t;

    typedef struct packed {
        logic        busy;
        logic [4:0]  rob_address;
        decode_rename_t instruction_packet; // all the necessary info is here, simpler interface
    } RS_Entry; // Reservation Station 

    typedef struct packed {
        logic        busy;
        logic [4:0]  rob_address;
        decode_rename_t instruction_packet; // all the necessary info is here, simpler interface
    } lsq_entry; //Load store unit entry

    typedef struct packed {
        logic             valid;       
        logic [31:0]      exec_result;  
        logic [4:0]       rob_idx; // ROB index of the instruction
        logic             branch; 
        decode_rename_t   instruction_packet;  
    } cdb_t; //Common Data Bus

    


endpackage