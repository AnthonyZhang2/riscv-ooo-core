module prefetcher # (
    parameter integer DATA_WIDTH = 32,
    parameter integer MASK_WIDTH = 4
) (
    input logic clk,rst,

    input logic [31:0] fetch_addr,
    input logic [MASK_WIDTH-1:0] fetch_rmask,
    input logic [MASK_WIDTH-1:0] fetch_wmask,
    output logic [DATA_WIDTH-1:0] fetch_rdata,
    input logic [DATA_WIDTH-1:0] fetch_wdata,
    output logic fetch_resp,

    output logic [31:0] cache_addr,
    output logic [MASK_WIDTH-1:0] cache_rmask,
    output logic [MASK_WIDTH-1:0] cache_wmask,
    input logic [DATA_WIDTH-1:0] cache_rdata,
    output logic [DATA_WIDTH-1:0] cache_wdata,
    input logic cache_resp,

    input logic on, // 1: prefetch, 0: don't prefetch
    input logic prefetch_on_access // 1: prefetch on each cache access, 0: prefetch on each cache miss
);

enum logic {
    fetching,
    prefetching
} state, state_next;

logic [31:0] prefetch_addr_reg, prefetch_addr_next;
logic [31:0] fetch_addr_delayed; // for edge case where fetch_addr changes as cache_resp goes high
logic [1:0] counter, counter_next;

logic fetch_request;
assign fetch_request = |{fetch_rmask, fetch_wmask};

always_ff @(posedge clk) begin 
    if (rst) begin
        state <= fetching;
        prefetch_addr_reg <= '0;
        fetch_addr_delayed <= '0;
        counter <= '0;
    end else begin
        state <= state_next;
        prefetch_addr_reg <= prefetch_addr_next;
        fetch_addr_delayed <= fetch_addr;
        counter <= counter_next;
    end
end

always_comb begin 
    fetch_rdata = cache_rdata;
    fetch_resp = cache_resp;

    cache_addr = fetch_addr;
    cache_rmask = fetch_rmask;
    cache_wmask = fetch_wmask;
    cache_wdata = fetch_wdata;

    counter_next = '0;

    prefetch_addr_next = prefetch_addr_reg;

    state_next = state;

    unique case (state)

        fetching: begin 
            if (fetch_request) begin
                if (counter == 2'b10 & !cache_resp)
                    counter_next = counter;
                else if (!cache_resp)
                    counter_next = counter + 2'b1;
            end

            if (cache_resp)
                prefetch_addr_next = {fetch_addr_delayed[31:5] + 27'b1, 5'b0}; // next line prefetcher, update next line addr on response

            if (cache_resp && on && (prefetch_on_access || (counter == 2'b10)))
                state_next = prefetching;
        end

        prefetching: begin
            fetch_rdata = 'x;
            fetch_resp = '0;

            cache_addr = prefetch_addr_reg;
            cache_rmask = '1; // when prefetching, just read from the cache
            cache_wmask = '0;
            cache_wdata = 'x;

            if (cache_resp)
                state_next = fetching;
        end

        default: begin
        end
    endcase
end


endmodule : prefetcher