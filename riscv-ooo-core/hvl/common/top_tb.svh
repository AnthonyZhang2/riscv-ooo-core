    longint timeout;

    longint icache_miss_count, dcache_miss_count, dcache_eviction_count, icache_request_count, dcache_request_count;

    longint num_branches, misprediction_counter;

    longint predicted_t0, predicted_t1, predicted_t2, predicted_t3;

    longint hash_collision_t1, hash_collision_t2, hash_collision_t3;

    longint mem_not_empty_count, mem_active_count;

    initial begin
        $value$plusargs("TIMEOUT_ECE411=%d", timeout);
        icache_miss_count <= '0;
        dcache_miss_count <= '0;
        dcache_eviction_count <= '0;
        icache_request_count <= '0;
        dcache_request_count <= '0;
        num_branches <= '0;
        misprediction_counter <= '0;
        predicted_t0 <= '0;
        predicted_t1 <= '0;
        predicted_t2 <= '0;
        predicted_t3 <= '0;
        hash_collision_t1 <= '0;
        hash_collision_t2 <= '0;
        hash_collision_t3 <= '0;
        mem_not_empty_count <= '0;
        mem_active_count <= '0;
    end

    mem_itf_banked mem_itf(.*);
    dram_w_burst_frfcfs_controller mem(.itf(mem_itf));
    // random_tb random_tb(.itf(mem_itf)); // For randomized testing

    mon_itf #(.CHANNELS(8)) mon_itf(.*);
    monitor #(.CHANNELS(8)) monitor(.itf(mon_itf));

    cpu dut(
        .clk            (clk),
        .rst            (rst),

        .bmem_addr  (mem_itf.addr  ),
        .bmem_read  (mem_itf.read  ),
        .bmem_write (mem_itf.write ),
        .bmem_wdata (mem_itf.wdata ),
        .bmem_ready (mem_itf.ready ),
        .bmem_raddr (mem_itf.raddr ),
        .bmem_rdata (mem_itf.rdata ),
        .bmem_rvalid(mem_itf.rvalid)
    );

    `include "rvfi_reference.svh"

    always @(posedge clk) begin
        if (mon_itf.halt) begin
            $finish;
        end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $fatal;
        end
        if (mem_itf.error != 0 || mon_itf.error != 0) begin
            $fatal;
        end
        timeout <= timeout - 1;

        // Performance Counters

        // Can increment counters here, or have an hdl counter and just display the value in the final block

        if (dut.instruction_prefetcher.counter == 2'b10 && dut.instruction_prefetcher.cache_resp) // we don't care about prefetch misses, only misses on request 
            icache_miss_count <= icache_miss_count + 1;
        if (dut.data_prefetcher.counter == 2'b10 && dut.data_prefetcher.cache_resp)
            dcache_miss_count <= dcache_miss_count + 1;

        if (dut.dcache.state == 2'b11 && dut.dcache.dfp_resp) // only dcache evictions are written back, so they're all we track
            dcache_eviction_count <= dcache_eviction_count + 1;

        if (dut.instruction_prefetcher.state == 1'b0 && dut.instruction_prefetcher.cache_resp)
            icache_request_count <= icache_request_count + 1;
        if (dut.data_prefetcher.state == 1'b0 && dut.data_prefetcher.cache_resp)
            dcache_request_count <= dcache_request_count + 1;

        if (dut.commit_bus.valid && dut.commit_bus.instruction_packet.branch) begin//instruction_packet.branch just says is branch instr
            num_branches <= num_branches + 1;
            // if (dut.fetch_module.branch_predictor.mispredicted) begin
            //     if (dut.fetch_module.predictor_info.provider_id == 1) begin
            //         if (dut.fetch_module.branch_predictor.t1_out.useful > 0)
            //             hash_collision_t1 <= hash_collision_t1 + 1;
            //     end else if (dut.fetch_module.predictor_info.provider_id == 2) begin
            //         if (dut.fetch_module.branch_predictor.t2_out.useful > 0)
            //             hash_collision_t2 <= hash_collision_t2 + 1;
            //     end else if (dut.fetch_module.predictor_info.provider_id == 3) begin
            //         if (dut.fetch_module.branch_predictor.t3_out.useful > 0)
            //             hash_collision_t3 <= hash_collision_t3 + 1;
            //     end
            // end
        end
        
        if (dut.commit_bus.valid && dut.commit_bus.branch) begin//commit_bus.branch changes the PC, means we mispredicted.
            misprediction_counter <= misprediction_counter + 1;
        end

        if (dut.fetch_module.tage_used) begin
            if (dut.fetch_module.predictor_info.provider_id == 0) begin
                predicted_t0 <= predicted_t0 + 1;
            end
            // end else if (dut.fetch_module.predictor_info.provider_id == 1) begin
            //     predicted_t1 <= predicted_t1 + 1;
            // end else if (dut.fetch_module.predictor_info.provider_id == 2) begin
            //     predicted_t2 <= predicted_t2 + 1;
            // end else if (dut.fetch_module.predictor_info.provider_id == 3) begin
            //     predicted_t3 <= predicted_t3 + 1;
            // end
        end

        if (dut.load_store_unit.head != dut.load_store_unit.tail) begin
            mem_not_empty_count <= mem_not_empty_count + 1;
            if (dut.load_store_unit.current_mem_exec)
                mem_active_count <= mem_active_count + 1;
        end

        
    end

    final begin 
        $display("Instruction cache miss rate: %f", real'(icache_miss_count) / icache_request_count);
        $display("Data cache miss rate: %f", real'(dcache_miss_count) / dcache_request_count);
        $display("Data cache eviction rate: %f", real'(dcache_eviction_count) / dcache_request_count);
        
        $display("Total Branches: %d", num_branches);
        $display("Mispredictions: %d", misprediction_counter);
        $display("Prediction Rate: %f%%", (real'(num_branches)-real'(misprediction_counter))/real'(num_branches));

        $display("\nTable 0 Predictions: %d", predicted_t0);
        $display("Table 1 Predictions: %d", predicted_t1);
        $display("Table 2 Predictions: %d", predicted_t2);
        $display("Table 3 Predictions: %d", predicted_t3);

        $display("\nHash Collision Table 1: %d", hash_collision_t1);
        $display("Hash Collision Table 2: %d", hash_collision_t2);
        $display("Hash Collision Table 3: %d", hash_collision_t3);

        $display("Load Store Unit Usage Rate: %f", real'(mem_active_count) / mem_not_empty_count);
    end


