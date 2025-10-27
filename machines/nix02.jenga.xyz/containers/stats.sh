#!/usr/bin/env bash
STATUS_FILE="/var/www/status.json"

# --- Detect cgroup layout ---
if [[ -f /sys/fs/cgroup/cpu.max ]]; then
    # cgroup v2
    CGROUP_VER=2
    CPU_MAX_FILE="/sys/fs/cgroup/cpu.max"
    CPU_STAT_FILE="/sys/fs/cgroup/cpu.stat"
else
    # cgroup v1
    CGROUP_VER=1
    CPU_QUOTA_FILE="/sys/fs/cgroup/cpu/cpu.cfs_quota_us"
    CPU_PERIOD_FILE="/sys/fs/cgroup/cpu/cpu.cfs_period_us"
    CPU_USAGE_FILE="/sys/fs/cgroup/cpuacct/cpuacct.usage"
fi

# --- Determine number of CPUs available (respecting quota) ---
if [[ $CGROUP_VER -eq 2 ]]; then
    read -r quota period < "$CPU_MAX_FILE"
    if [[ "$quota" == "max" ]]; then
        cpus_available=$(nproc)
    else
        cpus_available=$(awk -v q="$quota" -v p="$period" 'BEGIN { printf "%.2f", q / p }')
    fi
else
    quota=$(<"$CPU_QUOTA_FILE")
    period=$(<"$CPU_PERIOD_FILE")
    if (( quota == -1 )); then
        cpus_available=$(nproc)
    else
        cpus_available=$(awk -v q="$quota" -v p="$period" 'BEGIN { printf "%.2f", q / p }')
    fi
fi

# --- CPU usage percentage ---
if [[ $CGROUP_VER -eq 2 ]]; then
    usage1=$(grep usage_usec "$CPU_STAT_FILE" | awk '{print $2}')
    sleep 0.2
    usage2=$(grep usage_usec "$CPU_STAT_FILE" | awk '{print $2}')
    delta=$((usage2 - usage1))
    cpu_used=$(awk -v d="$delta" -v c="$cpus_available" 'BEGIN { printf "%.2f", (d / (200000 * c)) * 100 }')
else
    usage1=$(<"$CPU_USAGE_FILE")
    sleep 0.2
    usage2=$(<"$CPU_USAGE_FILE")
    delta=$((usage2 - usage1))
    cpu_used=$(awk -v d="$delta" -v c="$cpus_available" 'BEGIN { printf "%.2f", (d / (2e8 * c)) * 100 }')
fi

cpu_free=$(awk -v u="$cpu_used" 'BEGIN { printf "%.2f", (u > 100 ? 0 : 100 - u) }')

# --- GPU free percentage ---
if command -v nvidia-smi >/dev/null 2>&1; then
    gpu_util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null \
               | awk '{sum+=$1;n++} END{if(n>0)printf"%.2f",sum/n;else print 0}')
    gpu_free=$(awk -v u="${gpu_util:-0}" 'BEGIN { printf "%.2f", 100 - u }')
else
    gpu_free=100
fi

printf '{"cpu_free": %.2f, "gpu_free": %.2f, "cpus_available": %.2f}\n' \
    "$cpu_free" "$gpu_free" "$cpus_available" > "$STATUS_FILE"

