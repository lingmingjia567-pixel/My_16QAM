transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/demod_fir.vo}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/mod_fir.vo}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/my_nco_10m.vo}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/demod_p2s.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/top.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/mod_s2p.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/mod_mul.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/mod_16QAM.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/freq_div.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/demod_mul.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/demod_dec.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/demod_16QAM.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/carrier_generator.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/awgn_channel.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/mod_dd_ped.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/mod_loop_filter.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/mod_carrier_sync.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/mod_gardner_ted_8x.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/mod_timing_filter.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/mod_timing_nco.v}
vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/data_create.v}

vlog -vlog01compat -work work +incdir+C:/Users/21503/Desktop/My_16QAM-main {C:/Users/21503/Desktop/My_16QAM-main/top.vt}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L rtl_work -L work -voptargs="+acc"  top_vlg_tst

add wave *
view structure
view signals
run -all
