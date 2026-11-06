#!/system/bin/sh
# CPU min-freq lift for MatePad 11 (Snapdragon 865, schedutil).
# Stock minimums: 300000 / 710400 / 844800 (small / big / prime).
# Writing the policy head (cpu0/cpu4/cpu7) covers the whole cluster:
#   policy0 = cpu0-3, policy4 = cpu4-6, cpu7 = prime.
# Max freqs are already at the hardware table ceiling (1804800/2419200/2841600)
# and cannot be raised without a custom kernel.
echo 403200 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
echo 825600 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq
echo 960000 > /sys/devices/system/cpu/cpu7/cpufreq/scaling_min_freq
