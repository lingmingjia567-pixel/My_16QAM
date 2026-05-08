onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /top_vlg_tst/carrier_clk
add wave -noupdate /top_vlg_tst/reset_n
add wave -noupdate /top_vlg_tst/signal_clk
add wave -noupdate /top_vlg_tst/in_data
add wave -noupdate /top_vlg_tst/out_data
add wave -noupdate /top_vlg_tst/in_data_aligned
add wave -noupdate /top_vlg_tst/total_bits
add wave -noupdate /top_vlg_tst/error_bits
add wave -noupdate /top_vlg_tst/current_ber
add wave -noupdate /top_vlg_tst/start_calc
add wave -noupdate /top_vlg_tst/delay_line
add wave -noupdate -format Analog-Step -height 74 -max 2888863.9999999995 -min -2642912.0 /top_vlg_tst/i1/demod/timing_error
add wave -noupdate -format Analog-Step -height 74 -max 187231.0 -min -160104.0 /top_vlg_tst/i1/demod/timing_loop_out
add wave -noupdate -format Analog-Step -height 74 -max 19320.000000000004 -min -23626.0 /top_vlg_tst/i1/demod/u_carrier_sync/phase_error
add wave -noupdate -format Analog-Step -height 74 -max 19.0 -min 16.0 /top_vlg_tst/i1/demod/u_carrier_sync/freq_control_word
add wave -noupdate /top_vlg_tst/i1/mod/mod_out
add wave -noupdate -format Analog-Step -height 74 -max 458.99999999999994 -min -458.0 /top_vlg_tst/i1/channel/tx_signal
add wave -noupdate -format Analog-Step -height 74 -max 546.00000000000011 -min -524.0 /top_vlg_tst/i1/channel/rx_signal
add wave -noupdate -format Analog-Step -height 74 -max 96548.0 -min -106902.0 /top_vlg_tst/i1/demod/fir_i
add wave -noupdate -format Analog-Step -height 74 -max 101661.00000000001 -min -106479.0 /top_vlg_tst/i1/demod/fir_q
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {326083040740 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 352
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {326083040740 ps} {326191705941 ps}
