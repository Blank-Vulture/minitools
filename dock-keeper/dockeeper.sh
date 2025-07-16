#!/usr/bin/env bash
# DocKeeper v2.0 - Homebrew Cask更新時のDockアイコン復元ツール
# Author: Assistant
# License: MIT

set -euo pipefail

# === 設定 ===
readonly SCRIPT_NAME="DocKeeper"
readonly VERSION="2.2.0"
readonly LOG_DIR="${HOME}/.local/share/dockeeper"
readonly LOG_FILE="${LOG_DIR}/dockeeper.log"
readonly CONFIG_FILE="${LOG_DIR}/config.json"

# === カラー出力 ===
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# === グローバル変数 ===
DRY_RUN=false
VERBOSE=false

# === ヘルパー関数 ===
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
    
    case "${level}" in
        "ERROR")   echo -e "${RED}✗ ${message}${NC}" >&2 ;;
        "WARN")    echo -e "${YELLOW}⚠ ${message}${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✓ ${message}${NC}" ;;
        "INFO")    echo -e "${BLUE}ℹ ${message}${NC}" ;;
        *)         echo "${message}" ;;
    esac
}

progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf "%${remaining}s" | tr ' ' ' '
    printf "] %d%% (%d/%d)" "${percentage}" "${current}" "${total}"
}

show_help() {
    cat << EOF
${SCRIPT_NAME} v${VERSION} - Homebrew Cask更新時のDockアイコン復元ツール

使用法:
    $(basename "$0") [オプション]

オプション:
    -n, --dry-run       実際の変更を行わず、実行予定の操作を表示
    -v, --verbose       詳細な出力を表示
    -h, --help          このヘルプを表示
    --version           バージョン情報を表示

例:
    $(basename "$0")                # 通常実行
    $(basename "$0") --dry-run      # テスト実行
    $(basename "$0") -v             # 詳細出力

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--dry-run)   DRY_RUN=true; shift ;;
            -v|--verbose)   VERBOSE=true; shift ;;
            -h|--help)      show_help; exit 0 ;;
            --version)      echo "${SCRIPT_NAME} v${VERSION}"; exit 0 ;;
            *)              log "ERROR" "不明なオプション: $1"; show_help; exit 1 ;;
        esac
    done
}

setup_environment() {
    # ログディレクトリ作成
    if [[ ! -d "${LOG_DIR}" ]]; then
        mkdir -p "${LOG_DIR}" || {
            log "ERROR" "ログディレクトリの作成に失敗: ${LOG_DIR}"
            exit 1
        }
    fi
    
    # 設定ファイルの初期化
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        cat > "${CONFIG_FILE}" << 'EOF'
{
  "notification_enabled": true,
  "excluded_apps": [],
  "auto_install_deps": true
}
EOF
    fi
    
    log "INFO" "${SCRIPT_NAME} v${VERSION} を開始"
    [[ "${DRY_RUN}" == true ]] && log "WARN" "DRY-RUN モード: 実際の変更は行いません"
}

check_and_install_dependencies() {
    local deps_to_install=()
    
    # Homebrewチェック
    if ! command -v brew >/dev/null 2>&1; then
        log "ERROR" "Homebrewが必要です。https://brew.sh からインストールしてください"
        exit 1
    fi
    
    # Homebrew バージョンチェック（4.0以上でcaskアップグレード対応）
    local brew_version
    brew_version=$(brew --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
    local major_version
    major_version=$(echo "$brew_version" | cut -d'.' -f1)
    
    if [[ $major_version -lt 4 ]]; then
        log "ERROR" "Homebrew 4.0以上が必要です。現在のバージョン: $brew_version"
        log "INFO" "brew update && brew upgrade で最新版にアップグレードしてください"
        exit 1
    fi
    
    # dockutilチェック
    if ! command -v dockutil >/dev/null 2>&1; then
        log "WARN" "dockutil が見つかりません"
        deps_to_install+=("dockutil")
    fi
    
    # brew-cask-upgradeチェック（オプション）
    if ! command -v brew-cask-upgrade >/dev/null 2>&1; then
        log "INFO" "brew-cask-upgrade が見つかりません（オプション機能）"
        log "INFO" "より包括的な更新には 'brew tap buo/cask-upgrade && brew install brew-cask-upgrade' を実行してください"
    fi
    
    # 依存関係のインストール
    if [[ ${#deps_to_install[@]} -gt 0 ]]; then
        log "INFO" "必要な依存関係をインストールします: ${deps_to_install[*]}"
        
        if [[ "${DRY_RUN}" == false ]]; then
            for dep in "${deps_to_install[@]}"; do
                log "INFO" "インストール中: ${dep}"
                if brew install "${dep}"; then
                    log "SUCCESS" "${dep} のインストールが完了"
                else
                    log "ERROR" "${dep} のインストールに失敗"
                    exit 1
                fi
            done
        else
            log "INFO" "[DRY-RUN] インストールをスキップ: ${deps_to_install[*]}"
        fi
    fi
}



perform_updates() {
    log "INFO" "Homebrew更新を開始"
    
    if [[ "${DRY_RUN}" == false ]]; then
        # アップデート前のDock状態を保存
        log "INFO" "アップデート前のDock状態を記録中..."
        mapfile -t before_dock < <(dockutil --list 2>/dev/null || echo "")
        
        # Homebrewアップデート
        log "INFO" "brew update 実行中..."
        brew update || log "WARN" "brew update で警告が発生"
        
        log "INFO" "brew upgrade (formulae) 実行中..."
        brew upgrade || log "WARN" "brew upgrade で警告が発生"
        
        # Caskアップデート: brew-cask-upgradeがあれば使用、なければ標準コマンド
        if command -v brew-cask-upgrade >/dev/null 2>&1; then
            log "INFO" "brew cu (cask upgrade with brew-cask-upgrade) 実行中..."
            yes | brew cu -f -a || log "WARN" "brew cu で警告が発生"
        fi
        
        log "INFO" "brew upgrade --cask --greedy (標準cask upgrade) 実行中..."
        brew upgrade --cask --greedy || log "WARN" "brew upgrade --cask で警告が発生"
        
        log "INFO" "brew cleanup 実行中..."
        brew cleanup || log "WARN" "brew cleanup で警告が発生"
        
        # アップデート後のDock状態を取得
        log "INFO" "アップデート後のDock状態を確認中..."
        mapfile -t after_dock < <(dockutil --list 2>/dev/null || echo "")
        
        # 差分検出と復元
        restore_dock_items "${before_dock[@]}" "${after_dock[@]}"
        
    else
        log "INFO" "[DRY-RUN] 以下の操作を実行する予定:"
        log "INFO" "[DRY-RUN]   1. brew update"
        log "INFO" "[DRY-RUN]   2. brew upgrade (formulae)"  
        if command -v brew-cask-upgrade >/dev/null 2>&1; then
            log "INFO" "[DRY-RUN]   3. brew cu -f -a (with brew-cask-upgrade)"
            log "INFO" "[DRY-RUN]   4. brew upgrade --cask --greedy (standard)"
            log "INFO" "[DRY-RUN]   5. brew cleanup"
            log "INFO" "[DRY-RUN]   6. Dock差分確認と復元"
        else
            log "INFO" "[DRY-RUN]   3. brew upgrade --cask --greedy (standard)"
            log "INFO" "[DRY-RUN]   4. brew cleanup"
            log "INFO" "[DRY-RUN]   5. Dock差分確認と復元"
        fi
    fi
}

restore_dock_items() {
    local before_dock=("$@")
    local after_dock=()
    
    # 引数の分割（before_dockとafter_dockを分ける）
    local split_point=0
    for ((i=0; i<${#before_dock[@]}; i++)); do
        if [[ "${before_dock[i]}" == "---SPLIT---" ]]; then
            split_point=$i
            break
        fi
    done
    
    if [[ $split_point -eq 0 ]]; then
        # 実際の実装では、グローバル変数かファイルから取得
        mapfile -t after_dock < <(dockutil --list 2>/dev/null || echo "")
    else
        after_dock=("${before_dock[@]:$((split_point+1))}")
        before_dock=("${before_dock[@]:0:split_point}")
    fi
    
    # 消失アイテムの検出
    local to_restore=()
    for app in "${before_dock[@]}"; do
        if [[ -n "$app" ]] && ! printf '%s\n' "${after_dock[@]}" | grep -Fxq -- "$app"; then
            to_restore+=("$app")
        fi
    done
    
    # 復元処理
    if [[ ${#to_restore[@]} -gt 0 ]]; then
        log "INFO" "${#to_restore[@]} 個のアプリをDockに復元します"
        
        for ((i=0; i<${#to_restore[@]}; i++)); do
            local app="${to_restore[i]}"
            progress_bar $((i+1)) ${#to_restore[@]}
            
            if [[ "${DRY_RUN}" == false ]]; then
                if dockutil --add "$app" --no-restart 2>/dev/null; then
                    [[ "${VERBOSE}" == true ]] && log "SUCCESS" "復元完了: $app"
                else
                    log "WARN" "復元失敗: $app"
                fi
            else
                [[ "${VERBOSE}" == true ]] && log "INFO" "[DRY-RUN] 復元予定: $app"
            fi
        done
        
        echo # 改行
        
        if [[ "${DRY_RUN}" == false ]]; then
            log "INFO" "Dockを再起動中..."
            killall Dock 2>/dev/null || log "WARN" "Dock再起動に失敗"
        fi
        
        log "SUCCESS" "Dock復元処理が完了しました: ${#to_restore[@]} 個のアプリを復元"
        
    else
        log "SUCCESS" "Dockアイテムの復元は不要です"
    fi
}

# 通知機能は削除済み（ターミナル実行で不要）

cleanup() {
    log "INFO" "${SCRIPT_NAME} 実行完了"
}

main() {
    parse_args "$@"
    setup_environment
    check_and_install_dependencies
    perform_updates
    cleanup
}

# エラーハンドリング
trap 'log "ERROR" "スクリプトが予期せずに終了しました (Exit Code: $?)"; exit 1' ERR
trap 'cleanup' EXIT

# メイン実行
main "$@"