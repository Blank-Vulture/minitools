#!/usr/bin/env bash
# DocKeeper Performance Benchmark Suite
# 実行: ./benchmark_dockeeper.sh

set -euo pipefail

# 設定
readonly SCRIPT_PATH="$(dirname "$0")/dockeeper.sh"
readonly BENCHMARK_RUNS=5
readonly RESULTS_FILE="benchmark_results_$(date '+%Y%m%d_%H%M%S').json"
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 結果格納
declare -a execution_times=()
declare -a memory_usage=()

log_benchmark() {
    local level="$1"
    local message="$2"
    case "$level" in
        "INFO")    echo -e "${BLUE}📊 ${message}${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ ${message}${NC}" ;;
        "WARN")    echo -e "${YELLOW}⚠️  ${message}${NC}" ;;
        "ERROR")   echo -e "${RED}❌ ${message}${NC}" ;;
    esac
}

# システム情報取得
get_system_info() {
    log_benchmark "INFO" "システム情報収集中..."
    
    echo "=== System Information ==="
    echo "macOS Version: $(sw_vers -productVersion)"
    echo "CPU: $(sysctl -n machdep.cpu.brand_string)"
    echo "Memory: $(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024 "GB"}')"
    echo "Homebrew Version: $(brew --version | head -n1)"
    
    if command -v dockutil >/dev/null 2>&1; then
        echo "dockutil: $(dockutil --version)"
    else
        echo "dockutil: Not installed"
    fi
    echo
}

# 実行時間測定
measure_execution_time() {
    local command="$1"
    local description="$2"
    
    log_benchmark "INFO" "測定中: $description"
    
    local total_time=0
    local times=()
    
    for ((i=1; i<=BENCHMARK_RUNS; i++)); do
        local start_time
        start_time=$(python3 -c "import time; print(time.perf_counter())")
        
        # コマンド実行（出力は抑制）
        bash -c "$command" >/dev/null 2>&1 || true
        
        local end_time
        end_time=$(python3 -c "import time; print(time.perf_counter())")
        
        local duration
        duration=$(python3 -c "print($end_time - $start_time)")
        
        times+=("$duration")
        total_time=$(python3 -c "print($total_time + $duration)")
        
        printf "  Run %d: %.3f seconds\n" "$i" "$duration"
    done
    
    local avg_time
    avg_time=$(python3 -c "print($total_time / $BENCHMARK_RUNS)")
    
    # 標準偏差計算
    local variance=0
    for time in "${times[@]}"; do
        variance=$(python3 -c "print($variance + ($time - $avg_time) ** 2)")
    done
    local std_dev
    std_dev=$(python3 -c "import math; print(math.sqrt($variance / $BENCHMARK_RUNS))")
    
    log_benchmark "SUCCESS" "$description - 平均: ${avg_time}s (±${std_dev}s)"
    execution_times+=("$avg_time")
    
    return 0
}

# メモリ使用量測定
measure_memory_usage() {
    local command="$1"
    local description="$2"
    
    log_benchmark "INFO" "メモリ測定: $description"
    
    # macOS の time コマンドでメモリ使用量測定
    local memory_info
    memory_info=$(/usr/bin/time -l bash -c "$command" 2>&1 | grep "maximum resident set size" || echo "0")
    
    local memory_kb
    memory_kb=$(echo "$memory_info" | awk '{print $1}')
    
    if [[ -n "$memory_kb" && "$memory_kb" != "0" && "$memory_kb" =~ ^[0-9]+$ ]]; then
        local memory_mb
        memory_mb=$(python3 -c "print(round($memory_kb / 1024, 2))")
        log_benchmark "SUCCESS" "$description - メモリ使用量: ${memory_mb}MB"
        memory_usage+=("$memory_mb")
    else
        log_benchmark "WARN" "$description - メモリ使用量測定失敗"
        memory_usage+=("N/A")
    fi
}

# Dock操作性能測定
benchmark_dock_operations() {
    if ! command -v dockutil >/dev/null 2>&1; then
        log_benchmark "WARN" "dockutil が見つかりません。Dock操作ベンチマークをスキップ"
        return 0
    fi
    
    log_benchmark "INFO" "Dock操作性能測定開始"
    
    # 現在のDock状態を取得
    local current_dock_count
    current_dock_count=$(dockutil --list | wc -l)
    
    # Dock一覧取得性能
    measure_execution_time "dockutil --list" "Dock一覧取得"
    
    log_benchmark "SUCCESS" "現在のDockアイテム数: $current_dock_count"
}

# ベンチマーク結果をJSONで出力
save_results_json() {
    local timestamp
    timestamp=$(date -Iseconds)
    
    cat > "$RESULTS_FILE" << EOF
{
  "benchmark_info": {
    "timestamp": "$timestamp",
    "script_version": "DocKeeper v2.2.0",
    "runs_per_test": $BENCHMARK_RUNS,
    "system": {
      "os": "$(sw_vers -productVersion)",
      "cpu": "$(sysctl -n machdep.cpu.brand_string)",
      "memory_gb": $(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024}'),
      "homebrew_version": "$(brew --version | head -n1)"
    }
  },
  "results": {
    "help_command": {
      "avg_execution_time_s": ${execution_times[0]:-"null"},
      "memory_usage_mb": "${memory_usage[0]:-"N/A"}"
    },
    "version_command": {
      "avg_execution_time_s": ${execution_times[1]:-"null"},
      "memory_usage_mb": "${memory_usage[1]:-"N/A"}"
    },
    "dry_run_command": {
      "avg_execution_time_s": ${execution_times[2]:-"null"},
      "memory_usage_mb": "${memory_usage[2]:-"N/A"}"
    },
    "dock_list_operation": {
      "avg_execution_time_s": ${execution_times[3]:-"null"}
    }
  },
  "performance_targets": {
    "help_command_max_s": 1.0,
    "dry_run_max_s": 30.0,
    "memory_usage_max_mb": 50.0,
    "dock_operations_max_s": 2.0
  }
}
EOF
    
    log_benchmark "SUCCESS" "ベンチマーク結果を保存: $RESULTS_FILE"
}

# パフォーマンス分析
analyze_performance() {
    log_benchmark "INFO" "パフォーマンス分析中..."
    
    echo "=== Performance Analysis ==="
    
    # ヘルプコマンド分析
    if [[ -n "${execution_times[0]:-}" ]]; then
        local help_time="${execution_times[0]}"
        if (( $(python3 -c "print(int($help_time < 1.0))") )); then
            log_benchmark "SUCCESS" "ヘルプコマンド性能: 目標達成 (${help_time}s < 1.0s)"
        else
            log_benchmark "WARN" "ヘルプコマンド性能: 目標未達成 (${help_time}s >= 1.0s)"
        fi
    fi
    
    # Dry-run分析
    if [[ -n "${execution_times[2]:-}" ]]; then
        local dryrun_time="${execution_times[2]}"
        if (( $(python3 -c "print(int($dryrun_time < 30.0))") )); then
            log_benchmark "SUCCESS" "Dry-run性能: 目標達成 (${dryrun_time}s < 30.0s)"
        else
            log_benchmark "WARN" "Dry-run性能: 目標未達成 (${dryrun_time}s >= 30.0s)"
        fi
    fi
    
    # メモリ使用量分析
    for i in "${!memory_usage[@]}"; do
        local mem="${memory_usage[i]}"
        if [[ "$mem" != "N/A" && -n "$mem" ]]; then
            if (( $(python3 -c "print(int($mem < 50.0))") )); then
                log_benchmark "SUCCESS" "メモリ使用量: 目標達成 (${mem}MB < 50MB)"
            else
                log_benchmark "WARN" "メモリ使用量: 目標未達成 (${mem}MB >= 50MB)"
            fi
            break
        fi
    done
    
    echo
}

# レコメンデーション生成
generate_recommendations() {
    echo "=== Performance Recommendations ==="
    
    # 実行時間が遅い場合の提案
    if [[ -n "${execution_times[2]:-}" ]]; then
        local dryrun_time="${execution_times[2]}"
        if (( $(python3 -c "print(int($dryrun_time > 10.0))") )); then
            echo "• Dry-run実行が遅い場合は依存関係チェックの最適化を検討"
        fi
    fi
    
    # メモリ使用量の提案
    for mem in "${memory_usage[@]}"; do
        if [[ "$mem" != "N/A" && -n "$mem" ]]; then
            if (( $(python3 -c "print(int($mem > 30.0))") )); then
                echo "• メモリ使用量が多い場合は、配列の最適化を検討"
            fi
            break
        fi
    done
    
    echo "• 定期的なベンチマークでパフォーマンス回帰を監視"
    echo "• Dock操作回数が多い場合は、バッチ処理の最適化を検討"
    echo
}

# メイン実行
main() {
    echo "=== DocKeeper Performance Benchmark ==="
    echo "Target Script: $SCRIPT_PATH"
    echo "Benchmark Runs: $BENCHMARK_RUNS per test"
    echo
    
    # システム情報
    get_system_info
    
    # 基本コマンドのベンチマーク
    measure_execution_time "$SCRIPT_PATH --help" "Help Command"
    measure_memory_usage "$SCRIPT_PATH --help" "Help Command"
    
    measure_execution_time "$SCRIPT_PATH --version" "Version Command"
    measure_memory_usage "$SCRIPT_PATH --version" "Version Command"
    
    measure_execution_time "$SCRIPT_PATH --dry-run" "Dry-run Command"
    measure_memory_usage "$SCRIPT_PATH --dry-run" "Dry-run Command"
    
    # Dock操作ベンチマーク
    benchmark_dock_operations
    
    # 結果分析
    analyze_performance
    
    # JSON結果保存
    save_results_json
    
    # レコメンデーション
    generate_recommendations
    
    log_benchmark "SUCCESS" "ベンチマーク完了"
}

# 前提条件チェック
if [[ ! -f "$SCRIPT_PATH" ]]; then
    log_benchmark "ERROR" "スクリプトが見つかりません: $SCRIPT_PATH"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    log_benchmark "ERROR" "Python3が必要です（時間計算用）"
    exit 1
fi

main "$@" 