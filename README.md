# AX7020 / ZYNQ-7020 FPGA 开发模板

> 面向 AX7020 / ZYNQ-7020 的可复现 Vivado/Vitis 开发模板，支持 AI 辅助下从 RTL、仿真、综合到纯 PL 或 PS+PL 发布的脚本化流程。

## 项目定位

本模板固定面向 AX7020 开发板和 `xc7z020clg400-2` 器件，提供从 FPGA 纯 PL 设计到 ZYNQ PS+PL 软硬协同的统一工程骨架。

它更适合作为：

- AX7020 FPGA 项目的起始模板
- Vivado/Vitis 自动化流程的参考工程
- 从 RTL 设计逐步扩展到 ZYNQ 软件控制 PL 的开发入口
- 人与 AI 协作处理硬件、软件和构建问题的工程骨架

本仓库中的 AI 主要指 **AI 辅助工程开发流程**，模板本身不预置神经网络模型或 AI 推理加速器。

## 固定环境

- 开发板：AX7020
- 器件：`xc7z020clg400-2`
- 工具：Vivado/Vitis 2022.2

开始修改前，请先阅读 [`AGENTS.md`](AGENTS.md)。板级 IO 只参考 `doc/AX7020开发板 IO引脚分配总表.md`，项目配置以 `config.tcl` 为准。

## 两种开发模式

### 纯 PL

适合只需要 FPGA 逻辑和 bitstream 的设计。默认配置为：

```tcl
set use_bd 0
```

主要输出为 bitstream 和对应的发布 manifest。

### PS + PL

适合使用 ZYNQ ARM 处理器控制 PL、访问 DDR 或构建软件程序的项目。开启配置后：

```tcl
set use_bd 1
```

流程可以继续生成 bit、XSA、FSBL、ELF 和启动镜像。DDR、MIO 和 PS 相关参数由 `prj/bd.tcl` 管理。

## 快速开始

```powershell
# 初始化或重建 Vivado 工程
.\scripts\invoke-xilinx.cmd Vivado all

# RTL/XDC 修改后的最小流程
.\scripts\invoke-xilinx.cmd Vivado synth
.\scripts\invoke-xilinx.cmd Vivado build

# 仿真
.\scripts\invoke-xilinx.cmd Vivado sim -TbTop <TB顶层> -SimTime 1ms

# 开启 use_bd=1 后构建 PS 软件和启动镜像
.\scripts\invoke-xilinx.cmd Vitis all

# JTAG 下载与 QSPI 写入前预检
.\scripts\download-jtag.cmd
.\vitis\program-qspi.ps1 -PreflightOnly
```

旧的 `-Tool ... -Step ...` 命令写法仍然兼容，详细参数和最小流程请以 [`AGENTS.md`](AGENTS.md) 为准。

## 项目结构

```text
config.tcl                 # 唯一项目配置入口
AGENTS.md                  # 人与 AI 协作规则
rtl/                       # RTL、XDC、头文件和初始化数据
sim/                       # testbench、模型和仿真数据
vitis/src/                 # PS 软件源码
doc/                       # AX7020 板级 IO 和工具文档
prj/                       # Vivado 工程脚本和 BD 配置
vitis/run.tcl              # Vitis 自动化流程
scripts/                   # 构建、下载和清理脚本
```

## AI 协作入口

建议每次任务按以下顺序进行：

1. 先阅读 [`AGENTS.md`](AGENTS.md) 和 `config.tcl`。
2. 修改 RTL/XDC 后，优先运行 `Vivado synth` 或 `Vivado build`。
3. 修改工程结构、BD、IP、器件或 PS 外设时，运行 `Vivado all`。
4. PS+PL 硬件变化后，再运行 `Vitis update` 和 `Vitis build`。
5. 先查看启动器摘要，再到 `logs/` 中定位第一个真实错误。
6. 最终确认构建输出 `SUCCESS:`、`RESULT: status=PASS` 和预期产物；仿真还必须输出 `TEST_PASS`。

## 验收与生成物边界

Vivado/Vitis 工具成功不等于开发板功能已经验证。JTAG、串口、ILA 和 QSPI 操作前，需要人工确认供电、连接、目标文件和写入参数。

不要手动编辑脚本生成的工程、bit/XSA/ELF/BIN 或 manifest。`runs/`、缓存、仿真过程文件、Vitis 构建输出和日志均属于可再生过程文件，应按清理脚本管理。

```powershell
.\scripts\clean-generated.cmd -DryRun
```

## 当前边界

这是一个开发模板，不保证空模板直接实现具体业务功能。加入实际设计后，需要由使用者补充 RTL、XDC、testbench，以及在 PS+PL 模式下补充软件源码和真实板级验证。