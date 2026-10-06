# RV32IM Out-of-Order RISC-V Core

This project implements a 32-bit RISC-V processor in SystemVerilog with Tomasulo-style out-of-order execution and in-order retirement. The core includes register renaming, reservation stations, a reorder buffer, separate instruction and data caches, branch prediction, and next-line prefetching.

The repository contains the processor RTL along with directed and randomized tests, a banked burst-memory model, and scripts for simulation, lint, synthesis, and power analysis.

## Features

- RV32I integer arithmetic, logic, shifts, comparisons, loads, stores, branches, and jumps.
- RV32M multiplication, division, and remainder through sequential arithmetic units.
- Register renaming using reorder-buffer entries as tags for pending results.
- Separate reservation stations for integer/control instructions and multiply/divide instructions.
- Common data bus for forwarding completed results and waking dependent instructions.
- 32-entry reorder buffer for in-order retirement.
- Early execution of ready loads while conservatively handling older stores.
- Gshare branch predictor with recovery after incorrect predictions.
- Separate set-associative instruction and data caches using 32-byte cache lines.
- Next-line prefetchers for both instruction and data accesses.
- RVFI-based instruction monitoring with Spike used as the reference model.

The current core supports RV32IM but leaves out fence instructions, `ECALL`, `EBREAK`, CSR operations, compressed instructions, and floating-point instructions.

## Architecture

Instructions enter the processor in program order. During rename, destination registers receive reorder-buffer tags that identify where their future results will appear.

Reservation stations hold instructions until their operands become available and the required execution unit can accept them. Because of this, younger independent instructions can execute while older instructions wait on dependencies.

Completed results return over the common data bus, which updates waiting operands and ROB entries. The ROB then retires instructions in program order so speculative execution never changes architectural state out of order.

![Tomasulo-style processor architecture](riscv-ooo-core/docs/Tomasulo%27s%20CP1%20Submission.png)

### Fetch and control flow

![Out-of-order instruction fetch cycle](riscv-ooo-core/docs/OoO%20Fetch%20Cycle.drawio.png)

The fetch stage resets the program counter to `0xAAAAA000`. A 256-bit line buffer holds the current instruction-cache line, while an eight-entry instruction queue separates fetch from decode.

Conditional branches use a Gshare predictor built from program-counter bits and global branch history. Direct `JAL` targets get calculated during fetch rather than waiting for a later pipeline stage.

When a branch retires, the ROB sends predictor updates back to the front end. A misprediction redirects the PC and flushes younger speculative instructions.

The repository also contains a TAGE implementation in `hdl/tage_predictor.sv`, although the active predictor instantiated by `hdl/fetch.sv` currently uses Gshare.

### Scheduling and execution

The integer path and multiply/divide path each have an eight-entry reservation station.

Operands that have not finished yet carry ROB tags instead of values. They can receive their values either from a common-data-bus broadcast or during retirement.

The integer execution unit handles arithmetic, logic, comparisons, and control-flow calculations. Multiplication and division run through the `DW_mult_seq` and `DW_div_seq` DesignWare components.

A 16-entry load/store queue tracks memory instructions and whether their address and data operands have become ready.

Loads can execute before retirement when the ordering checks allow it. The scheduler stops searching for an early load once it encounters an older store, while stores only issue once they reach the head of the ROB. This keeps the memory ordering logic conservative while still allowing useful load reordering.

## Cache and memory subsystem

| Component | Current configuration |
| --- | --- |
| Instruction cache | 64 sets, 2 ways, 32-byte lines; 4 KiB data capacity |
| Data cache | 16 sets, 4 ways, 32-byte lines; 2 KiB data capacity |
| Data-cache write policy | Write-back, write-allocate |
| Instruction line buffer | One 32-byte cache line |
| Prefetching | Next-line instruction and data prefetching on misses |
| External memory interface | 32-bit addresses and 64-bit data beats |

The cache-line adapter arbitrates traffic from the instruction and data caches and converts between the core's 256-bit cache lines and the external burst-memory interface.

For simulation, the repository includes a banked DRAM model that supports multiple outstanding requests and out-of-order read responses.

## Repository layout

```text
riscv-ooo-core/
├── hdl/            Processor, caches, predictors, and memory-interface RTL
├── pkg/            Shared SystemVerilog types and instruction definitions
├── hvl/
│   ├── common/     Memory model, RVFI monitor, and Spike integration
│   ├── vcs/        Full-core and component testbenches
│   └── verilator/  Top-level testbench and C++ simulation harness
├── testcode/       Directed assembly programs and benchmark ELF files
├── sim/            Simulation Makefile, configuration, and analysis scripts
├── bin/            Program compilation, memory-image, and RVFI utilities
├── sram/           SRAM configurations, generation scripts, and output
├── lint/           SpyGlass lint flow
├── synth/          Design Compiler synthesis and power-analysis flows
├── docs/           Additional design and tool documentation
└── options.json    Clock, ISA, arithmetic-IP, and synthesis settings
```

The top-level processor module lives in [`cpu`](riscv-ooo-core/hdl/cpu.sv). Shared interfaces and instruction packet definitions live in [`pkg/types.sv`](riscv-ooo-core/pkg/types.sv).

## Build requirements

The Makefiles rely on Bash and standard Linux command-line tools. Run the project from Linux or a properly configured WSL environment.

I would also avoid checkout paths containing spaces because several build scripts interpolate paths directly into shell commands.

Simulation requires:

- GNU Make, Bash, Python 3, and standard Unix utilities such as `bc`.
- A RISC-V GNU toolchain exposing `riscv64-unknown-elf-gcc`, `riscv64-unknown-elf-objdump`, and `riscv64-unknown-elf-objcopy`, with RV32IM/ILP32 support.
- Synopsys VCS, or Verilator with a C++ compiler toolchain.
- DesignWare simulation models for `DW_mult_seq` and `DW_div_seq`, with `DW` pointing to the installation containing `sim_ver/`.
- SRAM Verilog models under `sram/output/`.
- A compatible Spike DPI library at `hvl/common/spike.so`.

Both simulation paths currently include the DesignWare models, so the Verilator flow still needs those models or compatible replacements.

Regenerating SRAMs requires OpenRAM through `OPENRAM` along with Synopsys Library Compiler. Synthesis also requires Design Compiler and the technology libraries selected through `FREEPDK45`.

## Running simulations

Run simulation commands from the `riscv-ooo-core/sim/` directory.

`PROG` can point to an assembly file, C source file, or RISC-V ELF. The build scripts compile or prepare the selected program, generate the memory image, and then start the full-core simulation.

### VCS

```bash
cd riscv-ooo-core/sim
make run_vcs_top_tb PROG=../testcode/ooo_test.s
```

There are several directed programs for testing branches, register dependencies, division by zero, and load/store scheduling:

```bash
make run_vcs_top_tb PROG=../testcode/branch_test.s
make run_vcs_top_tb PROG=../testcode/dependency_test.s
make run_vcs_top_tb PROG=../testcode/divide_by_zero_test.s
make run_vcs_top_tb PROG=../testcode/split_lsq_test.s
```



### Verilator

Before the first Verilator build, generate the RVFI reference include:

```bash
python3 ../bin/rvfi_reference.py 8 no_float
make run_verilator_top_tb PROG=../testcode/ooo_test.s
```

The repository also contains an RV32IM CoreMark executable. Since CoreMark takes substantially more cycles than the directed tests, run it with a larger timeout:

```bash
make run_verilator_top_tb PROG=../testcode/coremark_im.elf TIMEOUT=100000000
```

`TIMEOUT` controls the maximum simulation cycle count and defaults to `10000000`.

The included `coremark_imc.elf` binary requires compressed-instruction support, which the current core configuration does not enable.

### Component testbenches

The simulation Makefile includes VCS targets for testing individual components:

```bash
make run_vcs_FIFO_tb
make run_vcs_fetch_tb
make run_vcs_rob_tb
make run_vcs_reservation_tb
```

### Simulation output

Simulation and build logs appear under either `sim/vcs/` or `sim/verilator/`.

VCS generates FSDB waveforms, while Verilator generates FST waveforms.

During full-core tests, the RVFI monitor compares each retired instruction against Spike. The verification environment also reports memory-interface errors when it detects invalid behavior.

The full-core testbench tracks several performance-related statistics, including cache misses and evictions, branch prediction behavior, and load/store activity. Helper scripts under `sim/` calculate IPC and runtime from simulation output.

## Configuration and implementation tools

[`options.json`](riscv-ooo-core/options.json) controls the clock period, enabled ISA options, arithmetic IP dependencies, and synthesis configuration.

The current clock period setting uses `5800` picoseconds. This value represents the configured target rather than a measured post-synthesis timing result.

Cache geometry gets selected in `hdl/cpu.sv`, while RTL parameters control queue sizes. Some indexing logic assumes the current queue dimensions, so changing those values may require corresponding RTL changes rather than only modifying a parameter.

Once the required tools and technology libraries have been configured, run the following commands from the project root:

```bash
make -C riscv-ooo-core/lint lint
make -C riscv-ooo-core/synth synth
```

Synthesis reports appear under `synth/reports/`, with generated design outputs written to `synth/outputs/`.

The synthesis Makefile also provides `power_vcs` and `power_verilator` targets for activity-based power estimation after running simulation and synthesis.

## Verification scope

The included verification setup covers directed instruction execution, out-of-order dependency handling, branch recovery, memory scheduling, and arithmetic edge cases.

Random instruction generation and instruction-coverage components live under `hvl/vcs/`. The default full-core testbench runs the selected `PROG` against the banked memory model and checks retired instructions through RVFI and Spike.

The repository already contains the tests and infrastructure needed to evaluate the design, but measured results such as maximum clock frequency, area, benchmark performance, and passing regression status depend on actually running the corresponding flows in a configured environment.
