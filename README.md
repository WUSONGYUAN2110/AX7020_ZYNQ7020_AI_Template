# AX7020 / ZYNQ-7020 FPGA Development Template

English | [中文](README.zh-CN.md)

> A reproducible Vivado/Vitis development template for AX7020 / ZYNQ-7020, with scriptable AI-assisted workflows from RTL, simulation, and synthesis to pure-PL or PS+PL releases.

## Project Overview

This template targets the AX7020 development board and the `xc7z020clg400-2` device. It provides one engineering skeleton for pure FPGA-PL designs and ZYNQ PS+PL hardware/software co-design.

It is intended as:

- A starting point for AX7020 FPGA projects
- A reference project for Vivado/Vitis automation
- An entry point for extending RTL designs to ZYNQ software-controlled PL logic
- An engineering skeleton for human and AI collaboration on hardware, software, and build issues

In this repository, **AI** refers to an AI-assisted engineering workflow. The template does not include neural-network models or AI inference accelerators.

## Fixed Environment

- Development board: AX7020
- Device: `xc7z020clg400-2`
- Tools: Vivado/Vitis 2022.2

Before making changes, read [`AGENTS.md`](AGENTS.md). Board-level IO must be referenced only from `doc/AX7020开发板 IO引脚分配总表.md`, and project configuration is defined by `config.tcl`.

## Two Development Modes

### Pure PL

Use this mode for designs that only need FPGA logic and a bitstream. The default configuration is:

```tcl
set use_bd 0
```

The main outputs are the bitstream and its release manifest.

### PS + PL

Use this mode when the ZYNQ ARM processor controls PL logic, accesses DDR, or runs software. Enable it with:

```tcl
set use_bd 1
```

The flow can then generate the bitstream, XSA, FSBL, ELF, and boot image. DDR, MIO, and PS parameters are managed by `prj/bd.tcl`.

## Quick Start

```powershell
# Initialize or rebuild the Vivado project
.\scripts\invoke-xilinx.cmd Vivado all

# Minimal flow after RTL/XDC changes
.\scripts\invoke-xilinx.cmd Vivado synth
.\scripts\invoke-xilinx.cmd Vivado build

# Simulation
.\scripts\invoke-xilinx.cmd Vivado sim -TbTop <TB top level> -SimTime 1ms

# Build PS software and the boot image after enabling use_bd=1
.\scripts\invoke-xilinx.cmd Vitis all

# Preflight before JTAG programming and QSPI writing
.\scripts\download-jtag.cmd
.\vitis\program-qspi.ps1 -PreflightOnly
```

The older `-Tool ... -Step ...` command form remains supported. See [`AGENTS.md`](AGENTS.md) for detailed parameters and minimal flows.

## Project Structure

```text
config.tcl                 # Single project configuration entry point
AGENTS.md                  # Human/AI collaboration rules
rtl/                       # RTL, XDC, headers, and initialization data
sim/                       # Testbenches, models, and simulation data
vitis/src/                 # PS software sources
doc/                       # AX7020 board IO and tool documentation
prj/                       # Vivado project scripts and BD configuration
vitis/run.tcl              # Vitis automation flow
scripts/                   # Build, programming, and cleanup scripts
```

## AI Collaboration Entry Point

For each task, the recommended order is:

1. Read [`AGENTS.md`](AGENTS.md) and `config.tcl`.
2. After RTL/XDC changes, run `Vivado synth` or `Vivado build` first.
3. After project structure, BD, IP, device, or PS-peripheral changes, run `Vivado all`.
4. After PS+PL hardware changes, run `Vitis update` and `Vitis build`.
5. Check the launcher summary first, then locate the first real error in `logs/`.
6. Confirm `SUCCESS:`, `RESULT: status=PASS`, the expected artifacts, and `TEST_PASS` for simulation.

## Validation and Generated-Artifact Boundary

Successful Vivado/Vitis execution does not prove that the board behavior has been validated. Before JTAG, serial, ILA, or QSPI operations, manually confirm power, connections, target files, and programming parameters.

Do not manually edit generated projects, bit/XSA/ELF/BIN files, or manifests. `runs/`, caches, simulation intermediates, Vitis build outputs, and logs are reproducible process files and should be managed by the cleanup scripts.

```powershell
.\scripts\clean-generated.cmd -DryRun
```

## Current Scope

This is a development template and does not guarantee that a blank project implements a specific application. After adding a real design, users must provide RTL, XDC, and testbenches; PS+PL mode also requires software sources and real board validation.
