set_param general.maxThreads 1
launch_runs synth_1 -verbose
wait_on_run synth_1 -verbose
launch_runs impl_1 -to_step write_bitstream -verbose
wait_on_run impl_1 -verbose
exit
