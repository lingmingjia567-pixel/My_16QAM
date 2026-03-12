transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+D:/Quartus13.1/altera/program/My_16QAM {D:/Quartus13.1/altera/program/My_16QAM/demod_fir.vo}
vlog -vlog01compat -work work +incdir+D:/Quartus13.1/altera/program/My_16QAM {D:/Quartus13.1/altera/program/My_16QAM/demod_p2s.v}
vlog -vlog01compat -work work +incdir+D:/Quartus13.1/altera/program/My_16QAM {D:/Quartus13.1/altera/program/My_16QAM/top.v}
vlog -vlog01compat -work work +incdir+D:/Quartus13.1/altera/program/My_16QAM {D:/Quartus13.1/altera/program/My_16QAM/mod_s2p.v}
vlog -vlog01compat -work work +incdir+D:/Quartus13.1/altera/program/My_16QAM {D:/Quartus13.1/altera/program/My_16QAM/mod_mul.v}
vlog -vlog01compat -work work +incdir+D:/Quartus13.1/altera/program/My_16QAM {D:/Quartus13.1/altera/program/My_16QAM/mod_16QAM.v}
vlog -vlog01compat -work work +incdir+D:/Quartus13.1/altera/program/My_16QAM {D:/Quartus13.1/altera/program/My_16QAM/freq_div.v}
vlog -vlog01compat -work work +incdir+D:/Quartus13.1/altera/program/My_16QAM {D:/Quartus13.1/altera/program/My_16QAM/demod_mul.v}
vlog -vlog01compat -work work +incdir+D:/Quartus13.1/altera/program/My_16QAM {D:/Quartus13.1/altera/program/My_16QAM/demod_dec.v}
vlog -vlog01compat -work work +incdir+D:/Quartus13.1/altera/program/My_16QAM {D:/Quartus13.1/altera/program/My_16QAM/demod_16QAM.v}
vlog -vlog01compat -work work +incdir+D:/Quartus13.1/altera/program/My_16QAM {D:/Quartus13.1/altera/program/My_16QAM/carrier_generator.v}
vlog -vlog01compat -work work +incdir+D:/Quartus13.1/altera/program/My_16QAM {D:/Quartus13.1/altera/program/My_16QAM/sin_generator.v}
vlog -vlog01compat -work work +incdir+D:/Quartus13.1/altera/program/My_16QAM {D:/Quartus13.1/altera/program/My_16QAM/cos_generator.v}
vlog -vlog01compat -work work +incdir+D:/Quartus13.1/altera/program/My_16QAM {D:/Quartus13.1/altera/program/My_16QAM/data_create.v}

vlog -vlog01compat -work work +incdir+D:/Quartus13.1/altera/program/My_16QAM {D:/Quartus13.1/altera/program/My_16QAM/demod_16QAM.vt}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L rtl_work -L work -voptargs="+acc"  demod_16QAM_vlg_tst

add wave *
view structure
view signals
run -all
