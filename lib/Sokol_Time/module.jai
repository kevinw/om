#if OS.WINDOWS {
    stm_lib :: #foreign_library,no_dll "win/sokol_time_d3d11";
}

stm_setup :: ()        #foreign stm_lib;
stm_now   :: () -> u64 #foreign stm_lib;
stm_diff  :: (new: u64, old: u64) -> u64 #foreign stm_lib;

stm_sec   :: (ticks: u64) -> float64 #foreign stm_lib;
stm_ms    :: (ticks: u64) -> float64 #foreign stm_lib;
stm_us    :: (ticks: u64) -> float64 #foreign stm_lib;
stm_ns    :: (ticks: u64) -> float64 #foreign stm_lib;
