module cacheline_adapter (
    input clk, rst,

    input   logic   [31:0]      i_dfp_addr, // signals from cache
    input   logic               i_dfp_read,
    input   logic               i_dfp_write,
    output  logic   [255:0]     i_dfp_rdata,
    input   logic   [255:0]     i_dfp_wdata,
    output  logic               i_dfp_resp,

    input   logic   [31:0]      d_dfp_addr, // signals from cache
    input   logic               d_dfp_read,
    input   logic               d_dfp_write,
    output  logic   [255:0]     d_dfp_rdata,
    input   logic   [255:0]     d_dfp_wdata,
    output  logic               d_dfp_resp,

    output  logic   [31:0]      bmem_addr, // signals from dram
    output  logic               bmem_read,
    output  logic               bmem_write,
    output  logic   [63:0]      bmem_wdata,
    input   logic               bmem_ready, // unused, assumed always 1
    input   logic   [31:0]      bmem_raddr, // unused, only needed for multiple outstanding memory requests
    input   logic   [63:0]      bmem_rdata,
    input   logic               bmem_rvalid,

    output logic handling_dcache_req,
    output logic handling_icache_req
);

    logic [2:0] counter; // 0 to 3
    logic [63:0] burst0, burst1, burst2, burst3;
    logic [31:0] i_dfp_addr_reg;
    always_ff @(posedge clk) begin
        if (rst) i_dfp_addr_reg <= '0;
        else i_dfp_addr_reg <= i_dfp_addr;
    end


    always_ff @(posedge clk) begin
        if (rst) begin
            counter <= '0;
        end else if (bmem_rvalid | ((handling_icache_req & i_dfp_write) | (handling_dcache_req & d_dfp_write)))
            counter <= counter + 2'b1;
        if (counter == 3'b100) begin
            counter <= 3'b0;
        end 
    end

    always_ff @(posedge clk) begin 
        if (rst | d_dfp_resp | i_dfp_resp) begin
            handling_dcache_req <= '0;
            handling_icache_req <= '0;
        end else begin
            if (!handling_icache_req & bmem_ready &(d_dfp_read | d_dfp_write)) begin
                handling_dcache_req <= '1;
            end else if (!handling_dcache_req & bmem_ready & (i_dfp_read | i_dfp_write)) begin 
                handling_icache_req <= '1;
            end
        end
    end

    always_comb begin
        // bmem_read = dfp_read;
        if (handling_dcache_req) begin
            bmem_read = d_dfp_read;
            bmem_addr = d_dfp_addr;
            bmem_write = d_dfp_write & (counter != 3'b100);
            d_dfp_resp = (counter == 3'b100);
            i_dfp_resp = '0;
            bmem_wdata = d_dfp_wdata[(counter * 64) +: 64];
            d_dfp_rdata = {burst3, burst2, burst1, burst0};
            i_dfp_rdata = '0;
        end
        else if (handling_icache_req)  begin
            bmem_read = i_dfp_read;
            bmem_addr = i_dfp_addr_reg;
            bmem_write = i_dfp_write & (counter != 3'b100);
            i_dfp_resp = (counter == 3'b100);
            d_dfp_resp = '0;
            bmem_wdata = i_dfp_wdata[(counter * 64) +: 64];
            i_dfp_rdata = {burst3, burst2, burst1, burst0};
            d_dfp_rdata = '0;
        end else begin
            bmem_read = (bmem_raddr == '0) ? '0 : '0; // used raddr input for lint, doesn't do anything
            bmem_addr = '0;
            bmem_write = '0;
            bmem_wdata = '0;
            i_dfp_resp = '0;
            d_dfp_resp = '0;
            i_dfp_rdata = '0;
            d_dfp_rdata = '0;
        end
        // bmem_addr = dfp_addr;
        // bmem_write = dfp_write;
        // dfp_resp = (counter == 3'b100); // goes high as soon as full read is available or full write has been passed on
        // bmem_wdata = dfp_wdata[(counter * 64) +: 64]; // use counter bi ts to index 256 b it data
    end

    

    always_ff @(posedge clk) begin
        if (bmem_rvalid) begin
            case (counter)
                3'b000: burst0 <= bmem_rdata;
                3'b001: burst1 <= bmem_rdata;
                3'b010: burst2 <= bmem_rdata;
                3'b011: burst3 <= bmem_rdata;
            endcase
        end
    end
    // assign dfp_rdata = {burst3, burst2, burst1, burst0};

endmodule : cacheline_adapter