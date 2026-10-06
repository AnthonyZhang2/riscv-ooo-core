module reservation
import rv32i_types::*;
#(
    parameter integer NUM_STATIONS=8,
    parameter integer NUM_ROB_ENTRIES=32
)
(
    input logic clk,
    input logic rst,

    input RS_Entry new_rs_entry,
    input valid_input,
    // input logic [4:0] rob_address, // in new_rs_entry

    // this should be treated as a "functional unit ready/complete" signal, which for alu should be 1 unless stalled
    input logic exec_ready, //From exec unit. Tells us when we can send next instruction

    input cdb_t data_bus, commit_bus,

    output logic full, //We need to stall if this is 1

    output logic exec_valid,
    output logic [$clog2(NUM_ROB_ENTRIES)-1:0] out_rob_address,

    output decode_rename_t output_packet

);
localparam integer BUFFER_ADDRESS_WIDTH = $clog2(NUM_STATIONS); //Required bits to access each station
//integer start_index;
integer loop_index;

logic [BUFFER_ADDRESS_WIDTH-1:0] start_index;

RS_Entry rs[NUM_STATIONS];
logic [NUM_STATIONS-1:0] ready_entries;

logic full_reg;
logic [BUFFER_ADDRESS_WIDTH-1:0] next_available_spot;


logic [2:0] issue_index, last_issued_index;
logic [2:0] issue_index_reg;
logic [2:0] idx;
logic issue_valid;
logic issue_valid_reg;



assign full = full_reg;


assign exec_valid = issue_valid;


/*******************************************************************************
                        Valid Insert Location Checking
 *******************************************************************************/

always_comb begin
    for (integer i = 0; i < NUM_STATIONS; i++) begin
        ready_entries[i] = rs[i].busy && 
            (rs[i].instruction_packet.rs1_ready == 1'b1) && 
            (rs[i].instruction_packet.rs2_ready == 1'b1);
    end
end

always_comb begin
    full_reg = 1'b1;
    next_available_spot = '0;
    for (integer i = 0; i < NUM_STATIONS; i++) begin
        if (!rs[i].busy) begin
            full_reg = 1'b0;
            next_available_spot = $unsigned(BUFFER_ADDRESS_WIDTH'(i));
            break;
        end
    end
end


/*******************************************************************************
                    Valid Instruction to Execute Check
 *******************************************************************************/


/*******************************************************************************
                    Send out the previously found instruction
                    Also load up the next instruction into station
                    Also scan and see if we can load a tag and data in
 *******************************************************************************/

always_comb begin
    // currently_exec_instruction = !exec_ready;
    issue_valid = '0;
    issue_index = 'x;
    out_rob_address = 'x;
    output_packet = '0;
    for (integer i = 0; i < NUM_STATIONS; i++) begin
        if(ready_entries[start_index + $unsigned(3'(i))]) begin
            issue_valid = 1'b1;
            issue_index = start_index + $unsigned(3'(i));
            out_rob_address = rs[issue_index].rob_address;
            output_packet = rs[issue_index].instruction_packet;
            break;
        end
    end
end

always_ff @(posedge clk) begin // rs updates
    if (rst) begin
        for (integer i = 0; i < NUM_STATIONS; i++) begin
            rs[i] <= '0;
        end
    end else begin
        if (valid_input && !full) begin
            rs[next_available_spot] <= new_rs_entry;
        end
        if (commit_bus.valid) begin
            for (integer i = 0; i < NUM_STATIONS; i++) begin
                if (rs[i].busy) begin 
                    if(rs[i].instruction_packet.rs1_data[4:0] == commit_bus.rob_idx) begin // See decode, rob address is put in rs1_data
                        if(rs[i].instruction_packet.rs1_ready == 1'b0) begin
                            rs[i].instruction_packet.rs1_data <= commit_bus.exec_result;
                            rs[i].instruction_packet.rs1_ready <= 1'd1; // Mark operand as ready
                        end 
                    end
                    if(rs[i].instruction_packet.rs2_data[4:0] == commit_bus.rob_idx) begin
                        if(rs[i].instruction_packet.rs2_ready == 1'b0) begin
                            rs[i].instruction_packet.rs2_data <= commit_bus.exec_result;
                            rs[i].instruction_packet.rs2_ready <= 1'd1; // Mark operand as ready
                        end 
                    end
                end
            end
        end
        if (data_bus.valid) begin
            for (integer i = 0; i < NUM_STATIONS; i++) begin
                if (rs[i].busy) begin 
                    if(rs[i].instruction_packet.rs1_data[4:0] == data_bus.rob_idx) begin // See decode, rob address is put in rs1_data
                        if(rs[i].instruction_packet.rs1_ready == 1'b0) begin
                            rs[i].instruction_packet.rs1_data <= data_bus.exec_result;
                            rs[i].instruction_packet.rs1_ready <= 1'd1; // Mark operand as ready
                        end 
                    end
                    if(rs[i].instruction_packet.rs2_data[4:0] == data_bus.rob_idx) begin
                        if(rs[i].instruction_packet.rs2_ready == 1'b0) begin
                            rs[i].instruction_packet.rs2_data <= data_bus.exec_result;
                            rs[i].instruction_packet.rs2_ready <= 1'd1; // Mark operand as ready
                        end 
                    end
                end
            end
        end
        if (exec_ready && issue_valid) begin // functional unit has completed execution
            rs[issue_index].busy <= '0;
        end
    end
end

always_ff @(posedge clk) begin // start_index updates
    if (rst) begin
        start_index <= '0;
    end else if (exec_ready && issue_valid) begin // functional unit has completed execution
        start_index <= start_index + 3'b1;
    end
end


/*******************************************************************************
                        Fill in the next location
 *******************************************************************************/

endmodule : reservation