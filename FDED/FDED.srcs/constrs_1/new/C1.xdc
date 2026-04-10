set_property PACKAGE_PIN AK17 [get_ports clk_p]
set_property PACKAGE_PIN AK16 [get_ports clk_n]
set_property IOSTANDARD LVDS [get_ports clk_p]
set_property IOSTANDARD LVDS [get_ports clk_n]

set_property PACKAGE_PIN N27 [get_ports uart_rxd]
set_property PACKAGE_PIN K22 [get_ports uart_txd]
set_property IOSTANDARD LVCMOS18 [get_ports uart_rxd]
set_property IOSTANDARD LVCMOS18 [get_ports uart_txd]

create_clock -name sys_clk -period 5.000 [get_ports clk_p]