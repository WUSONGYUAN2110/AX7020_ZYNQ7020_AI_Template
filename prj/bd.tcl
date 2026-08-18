# Block Design 配置脚本，由 prj/run.tcl 的 bd 步骤调用。

global template_config

# 创建 Block Design
set design_name "system"

# AX7020 ZYNQ7020 板级 PS 外设选项统一配置在根目录 config.tcl。
set enable_qspi_boot $template_config(enable_qspi_boot)
set enable_uart1     $template_config(enable_uart1)
set uart1_io         $template_config(uart1_io)
set enable_sd0       $template_config(enable_sd0)
set enable_gpio_mio  $template_config(enable_gpio_mio)
set enable_fclk0     $template_config(enable_fclk0)
set fclk0_mhz        $template_config(fclk0_mhz)

create_bd_design $design_name
current_bd_design $design_name

# 添加 ZYNQ7 Processing System
set ps7 [create_bd_cell -type ip \
    -vlnv xilinx.com:ip:processing_system7:5.5 ps7]

# 板级参数配置
# DDR 拓扑见 doc/AX7020开发板 IO引脚分配总表.md；PS 晶振为 33.333333 MHz。
# 实物确认使用两颗 H5TQ4G63CFRROC；Vivado 采用其兼容的
# MT41J256M16 RE-125 预设（DDR3、32-bit、533.333 MHz）。
# AXI GP0 默认关闭；在本文件末尾“添加自定义 PL IP 核”处启用并添加 IP。
set_property -dict [list \
    CONFIG.PCW_CRYSTAL_PERIPHERAL_FREQMHZ     {33.333333} \
    CONFIG.PCW_UIPARAM_DDR_MEMORY_TYPE        {DDR 3} \
    CONFIG.PCW_UIPARAM_DDR_PARTNO             {MT41J256M16 RE-125} \
    CONFIG.PCW_UIPARAM_DDR_DRAM_WIDTH         {32 Bits} \
    CONFIG.PCW_UIPARAM_DDR_FREQ_MHZ           {533.333} \
    CONFIG.PCW_PRESET_BANK0_VOLTAGE           {LVCMOS 3.3V} \
    CONFIG.PCW_PRESET_BANK1_VOLTAGE           {LVCMOS 1.8V} \
    CONFIG.PCW_USE_M_AXI_GP0                  {0} \
] $ps7

if {$enable_fclk0} {
    set_property -dict [list \
        CONFIG.PCW_EN_CLK0_PORT              {1} \
        CONFIG.PCW_EN_RST0_PORT              {1} \
        CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ  $fclk0_mhz \
    ] $ps7
} else {
    set_property -dict [list \
        CONFIG.PCW_EN_CLK0_PORT {0} \
        CONFIG.PCW_EN_RST0_PORT {0} \
    ] $ps7
}

# PS 外设使能
if {$enable_uart1} {
    # PS UART1 默认使用扩展连接器上的 MIO8/9；外部收发器和接线由人工确认。
    set_property CONFIG.PCW_UART1_PERIPHERAL_ENABLE {1} $ps7
    set_property CONFIG.PCW_UART1_UART1_IO           $uart1_io $ps7
}

if {$enable_qspi_boot} {
    # Quad-SPI Flash（MIO1-6，x4 single-SS）。
    # 固化启动必须在生成 XSA 前启用；否则旧 FSBL/BOOT.bin 不能可靠初始化 QSPI。
    set_property CONFIG.PCW_QSPI_PERIPHERAL_ENABLE    {1} $ps7
    set_property CONFIG.PCW_QSPI_QSPI_IO              {MIO 1 .. 6} $ps7
    set_property CONFIG.PCW_QSPI_GRP_SINGLE_SS_ENABLE {1} $ps7
    # AX7020 uses one x4 QSPI Flash on MIO1..6:
    # SS, IO0, IO1, IO2/HOLD_B, IO3/WP_B and SCLK.
    # The group and data-mode selections must both be explicit so that
    # Vivado generates the PS MIO mux as qspi0_* rather than GPIO.
    set_property CONFIG.PCW_QSPI_GRP_SINGLE_SS_IO     {MIO 1 .. 6} $ps7
    set_property CONFIG.PCW_SINGLE_QSPI_DATA_MODE     {x4} $ps7
}

if {$enable_sd0} {
    # SD0（MIO40-45）；板载卡检测为 MIO47。
    set_property CONFIG.PCW_SD0_PERIPHERAL_ENABLE {1} $ps7
    set_property CONFIG.PCW_SD0_SD0_IO            {MIO 40 .. 45} $ps7
    set_property CONFIG.PCW_SD0_GRP_CD_ENABLE     {1} $ps7
    set_property CONFIG.PCW_SD0_GRP_CD_IO         {MIO 47} $ps7
}

if {$enable_gpio_mio} {
    # GPIO MIO（PS LED: MIO0/MIO13；PS KEY: MIO50/MIO51）
    set_property CONFIG.PCW_GPIO_MIO_GPIO_ENABLE  {1} $ps7
    set_property CONFIG.PCW_GPIO_MIO_GPIO_IO      {MIO} $ps7
}

# 将 DDR 和 FIXED_IO 引出为顶层端口
apply_bd_automation \
    -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "0"} \
    $ps7

# 添加自定义 PL IP 核
