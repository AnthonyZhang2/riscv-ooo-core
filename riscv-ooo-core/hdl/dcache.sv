module dcache # (
    parameter integer SETS = 16,
    parameter integer WAYS = 4
) (
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp,

    input logic adapter_handling
);

localparam SET_WIDTH = $clog2(SETS);
localparam WAY_WIDTH = (WAYS > 1) ? $clog2(WAYS) : 1;

    enum logic [1:0] {
        idle,
        compare_tag,
        allocate,
        write_back
    } state, state_next;

    logic [WAYS-1:0] data_web, tag_web, dirty_web, valid_web;
    logic csb;
    logic [WAYS-1:0] valid_write, dirty_write;
    logic [WAYS-1:0][26-SET_WIDTH:0] tag_write, tag_read;
    logic [SET_WIDTH-1:0] set;
    logic [WAYS-1:0][255:0] data_read;
    logic [255:0] data_write;
    logic [WAYS-2:0] lru_read, lru_write;
    logic hit;
    logic [WAY_WIDTH-1:0] hit_way;
    logic [WAY_WIDTH-1:0] lru_way;
    logic [4:0] offset;
    logic [WAYS-1:0] valid_read, dirty_read;
    logic [31:0] data_wmask;
    logic lru_web;
    logic [26-SET_WIDTH:0] tag;
    logic [3:0] ufp_rmask_reg, ufp_wmask_reg;
    // logic [4:0] offset_reg;
    logic [31:0] ufp_addr_reg, ufp_wdata_reg;
    // logic [SET_WIDTH-1:0] set_reg;
    // logic [26-SET_WIDTH:0] tag_reg;
    logic [26-SET_WIDTH:0] tag_wb_reg, tag_wb_next;

    logic [WAYS-1:0] hit_array;
    //unsigned integer lru_traverse, lru_addr;
    logic [WAY_WIDTH:0] lru_traverse;  
    logic [WAY_WIDTH:0] lru_addr;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= idle;
            ufp_rmask_reg <= '0;
            ufp_wmask_reg <= '0;
            // offset_reg <= '0;
            ufp_addr_reg <= '0;
            // set_reg <= '0;
            // tag_reg <= '0;
            tag_wb_reg <= '0;
            ufp_wdata_reg <= '0;
            dfp_read <= '0;
        end else begin
            state <= state_next;
            // gate necessary inputs for timing
            // offset_reg <= offset;
            
            // set_reg <= set;
            // tag_reg <= tag;
            tag_wb_reg <= tag_wb_next;
            dfp_read <= (state_next == allocate & (state == compare_tag | !adapter_handling)); // write also needs to be fixed for cp3
            if (state == idle) begin
                ufp_addr_reg <= ufp_addr;
                ufp_rmask_reg <= ufp_rmask;
                ufp_wmask_reg <= ufp_wmask; 
                ufp_wdata_reg <= ufp_wdata;
            end
        end
    end

    always_comb begin
        csb = '0; // everything reads by default
        data_wmask = {28'b0, ufp_wmask_reg} << {ufp_addr_reg[4:2], 2'b0};

        lru_web = '1;

        tag = (state == idle) ? ufp_addr[31:SET_WIDTH+5] : ufp_addr_reg[31:SET_WIDTH+5];

        // hit = (valid_read[0] && tag_reg == tag_read[0]) | (valid_read[1] && tag_reg == tag_read[1]) | (valid_read[2] && tag_reg == tag_read[2]) | (valid_read[3] && tag_reg == tag_read[3]);
        for (integer i = 0; i < WAYS; i++) begin
            hit_array[i] = (valid_read[i] && tag == tag_read[i]);
        end
        hit = |hit_array;

        hit_way = '0;
        // if (tag_reg == tag_read[1] && valid_read[1]) hit_way = 2'b01;
        // if (tag_reg == tag_read[2] && valid_read[2]) hit_way = 2'b10;
        // if (tag_reg == tag_read[3] && valid_read[3]) hit_way = 2'b11;
        for (integer i = 1; i < WAYS; i++) begin
            if (hit_array[i] & (WAYS > 1)) begin 
                hit_way = $unsigned((WAY_WIDTH)'(i));
                break;
            end
        end

        tag_wb_next = tag_wb_reg;

        state_next = state;

        ufp_rdata = 'x;
        ufp_resp = '0;

        tag_write = '0;
        valid_write = '0;
        dirty_write = '0;

        tag_web = '1;
        dirty_web = '1;
        valid_web = '1;
        data_web = '1;
        set = (state == idle) ? ufp_addr[SET_WIDTH+4:5] : ufp_addr_reg[SET_WIDTH+4:5];
        offset = (state == idle) ? ufp_addr[4:0] : ufp_addr_reg[4:0];
        

        data_write = 'x;
        data_write[({5'b0, offset[4:2]} << 5) +: 32] = ufp_wdata_reg;

        if (ufp_rmask_reg[0]) ufp_rdata[7:0] = data_read[hit_way][({3'b0, offset} << 3) +: 8];
        if (ufp_rmask_reg[1]) ufp_rdata[15:8] = data_read[hit_way][(({3'b0, offset + 1}) << 3) +: 8];
        if (ufp_rmask_reg[2]) ufp_rdata[23:16] = data_read[hit_way][(({3'b0, offset + 2}) << 3) +: 8];
        if (ufp_rmask_reg[3]) ufp_rdata[31:24] = data_read[hit_way][(({3'b0, offset + 3}) << 3) +: 8];

        dfp_addr = ufp_addr_reg & 32'hFFFFFFE0; 
        dfp_wdata = data_read[hit_way];
        dfp_write = (state == write_back);
        // dfp_read = (state == allocate);

        // lru_way = '0;
        // unique casez (lru_read)
        //     3'b?11: lru_way = 2'b00;
        //     3'b?01: lru_way = 2'b01;
        //     3'b1?0: lru_way = 2'b10;
        //     3'b0?0: lru_way = 2'b11;
        // endcase

        lru_traverse = '0;
        for (integer i = 0; i < WAY_WIDTH; i++) begin 
            lru_traverse += (lru_traverse + 3'd1 + (!lru_read[lru_traverse]));
        end
        lru_way = '0;
        if (WAYS > 1) lru_way = (WAY_WIDTH'(lru_traverse)) + $unsigned(WAY_WIDTH'(1));

        // lru_write = '0;
        // unique case (hit_way)
        //     2'b00: lru_write = lru_read & 3'b100;
        //     2'b01: lru_write = (lru_read | 3'b010) & 3'b110;
        //     2'b10: lru_write = (lru_read & 3'b011) | 3'b001;
        //     2'b11: lru_write = lru_read | 3'b101;
        // endcase

        lru_write = lru_read;
        lru_addr = '0;
        for (integer i = WAY_WIDTH-1; i >= 0; i--) begin 
            lru_write[lru_addr] = hit_way[i];
            lru_addr += (lru_addr + 3'd1 + hit_way[i]);
        end
        
        unique case (state)
            idle: begin
                if ((ufp_rmask | ufp_wmask) != 4'b0) // move to "hit" state if valid cpu request
                    state_next = compare_tag;
            end
            compare_tag: begin // cache hit moves to idle, clean miss moves to allocate, dirty miss moves to writeback
                if (hit && valid_read[hit_way]) begin // cache hit (tag match and valid entry)
                    ufp_resp = '1; // read hit, data already goes to ufp_rdata

                    if (ufp_wmask_reg != 4'b0) begin // write hit
                        data_web[hit_way] = '0;
                        dirty_web[hit_way] = '0;
                        dirty_write[hit_way] = '1;
                    end

                    lru_web = '0; // write to lru table when cache is done with line
                    state_next = idle;
                end

                else begin // cache miss
                    tag_web[lru_way] = '0;
                    valid_web[lru_way] = '0;
                    dirty_web[lru_way] = '0;
                    valid_write[lru_way] = '1;
                    tag_write[lru_way] = tag;
                    dirty_write[lru_way] = (ufp_wmask_reg != 4'b0); // cache line is dirty if write

                    if (valid_read[lru_way] == 1'b0 || dirty_read[lru_way] == 1'b0) begin // no writeback
                        state_next = allocate; // dfp_read will go high at posedge
                    end else begin // dirty, need to writeback
                        tag_wb_next = tag_read[lru_way];
                        state_next = write_back;
                    end
                end
            end
            allocate: begin
                if (dfp_resp) begin
                    state_next = idle;
                    data_write = dfp_rdata;
                    data_web[hit_way] = '0;
                    data_wmask = '1;
                end
            end
            write_back: begin
                dfp_addr = {tag_wb_next, set, 5'b0}; // write to old address
                dfp_wdata = data_read[lru_way];
                if (dfp_resp) begin
                    state_next = allocate; // dfp_read will go high at posedge
                end
            end
        endcase
    end

    generate for (genvar i = 0; i < WAYS; i++) begin : arrays
        dcache_data_array data_array ( // important: in dcache_data_array.json, set num_words = SETS
            .clk0       (clk),
            .csb0       (csb),
            .web0       (data_web[i]),
            .wmask0     (data_wmask),
            .addr0      (set),
            .din0       (data_write),
            .dout0      (data_read[i])
        );
        dcache_tag_array tag_array ( // important: in dcache_tag_array.json, set num_words = SETS, word_size = 27-SET_WIDTH, write_size = 27-SET_WIDTH
            .clk0       (clk),
            .csb0       (csb),
            .web0       (tag_web[i]),
            .addr0      (set),
            .din0       (tag_write[i]),
            .dout0      (tag_read[i])
        );
        sp_ff_array #(.S_INDEX(SET_WIDTH), .WIDTH(1)) valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (csb),
            .web0       (valid_web[i]),
            .addr0      (set),
            .din0       (valid_write[i]),
            .dout0      (valid_read[i])
        );
        sp_ff_array #(.S_INDEX(SET_WIDTH), .WIDTH(1)) dirty_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (csb),
            .web0       (dirty_web[i]),
            .addr0      (set),
            .din0       (dirty_write[i]),
            .dout0      (dirty_read[i])
        );
    end endgenerate

    sp_ff_array #(
        .S_INDEX(SET_WIDTH), .WIDTH      (WAYS-1)
    ) lru_array (
        .clk0       (clk),
        .rst0       (rst),
        .csb0       (csb),
        .web0       (lru_web),
        .addr0      (set),
        .din0       (lru_write),
        .dout0      (lru_read)
    );

endmodule
