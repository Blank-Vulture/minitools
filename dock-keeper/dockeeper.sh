#!/usr/bin/env bash
# DocKeeper v2.0 - Homebrew Cask更新時のDockアイコン復元ツール
# Author: Assistant
# License: MIT

set -euo pipefail

# === 設定 ===
readonly SCRIPT_NAME="DocKeeper"
readonly VERSION="2.2.0"

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

🎯 主な機能:
  • Homebrew Caskアプリの一括更新
  • 更新で消失したDockアイコンの自動復元
  • 安全な実行前確認プロンプト

📋 使用法:
    $(basename "$0") [オプション]

🔧 オプション:
    -n, --dry-run       実際の変更を行わず、実行予定の操作を表示
    -v, --verbose       詳細な出力を表示
    -h, --help          このヘルプを表示
    --version           バージョン情報を表示

💡 使用例:
    $(basename "$0") --dry-run      # 初回実行推奨: テスト実行
    $(basename "$0")                # 通常実行（確認プロンプトあり）
    $(basename "$0") -v             # 詳細出力付き実行
    $(basename "$0") --dry-run -v   # 詳細テスト実行

🚀 実行ステップ:
    1. 依存関係チェック (Homebrew, dockutil, brew-cask-upgrade)
    2. 現在のDock状態を記録
    3. 実行確認プロンプト（実際の実行時のみ）
    4. Homebrew更新実行 (brew cu -f -a 包括的更新)
    5. Dock差分検出と復元

📊 システム要件:
    • macOS 15.5+
    • Homebrew 4.0+
    • dockutil (自動インストール)
    • brew-cask-upgrade (自動インストール、推奨)

💬 初回実行時は --dry-run オプションでテスト実行することを強く推奨します

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
    log "INFO" "${SCRIPT_NAME} v${VERSION} を開始"
    [[ "${DRY_RUN}" == true ]] && log "WARN" "DRY-RUN モード: 実際の変更は行いません"
    
    # 実行モードの明示
    if [[ "${DRY_RUN}" == true ]]; then
        log "INFO" "🧪 テスト実行モード（変更なし）"
    else
        log "INFO" "🚀 本番実行モード（実際に変更を実行）"
        echo "   💡 テスト実行する場合: $(basename "$0") --dry-run"
        echo "   💡 詳細出力が必要な場合: $(basename "$0") --verbose"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

check_and_install_dependencies() {
    log "INFO" "🔍 依存関係チェックを開始"
    local deps_to_install=()
    
    # Homebrewチェック
    log "INFO" "  Homebrewの確認中..."
    if ! command -v brew >/dev/null 2>&1; then
        log "ERROR" "Homebrewが必要です。https://brew.sh からインストールしてください"
        exit 1
    fi
    
    # Homebrew バージョンチェック（4.0以上でcaskアップグレード対応）
    log "INFO" "  Homebrewバージョンの確認中..."
    local brew_version
    brew_version=$(brew --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
    local major_version
    major_version=$(echo "$brew_version" | cut -d'.' -f1)
    
    if [[ $major_version -lt 4 ]]; then
        log "ERROR" "Homebrew 4.0以上が必要です。現在のバージョン: $brew_version"
        log "INFO" "brew update && brew upgrade で最新版にアップグレードしてください"
        exit 1
    fi
    log "SUCCESS" "  Homebrew $brew_version が利用可能"
    
    # dockutilチェック
    log "INFO" "  dockutilの確認中..."
    if ! command -v dockutil >/dev/null 2>&1; then
        log "WARN" "  dockutil が見つかりません"
        deps_to_install+=("dockutil")
    else
        log "SUCCESS" "  dockutil が利用可能"
    fi
    
    # brew-cask-upgradeチェック（推奨）
    log "INFO" "  brew cu コマンドの確認中..."
    
    # 複数のアプローチでbrew cuの可用性をチェック
    local brew_cu_available=false
    
    # アプローチ1: brew cu --help を試行
    if brew cu --help >/dev/null 2>&1; then
        brew_cu_available=true
        log "SUCCESS" "  brew cu コマンドが利用可能（--help で確認）"
    # アプローチ2: brew tap でbuo/cask-upgradeの存在確認
    elif brew tap | grep -q "buo/cask-upgrade"; then
        # tapは存在するが、何らかの理由でコマンドが見つからない場合の再確認
        if brew cu --version >/dev/null 2>&1 || brew cu 2>&1 | grep -q "Usage:"; then
            brew_cu_available=true
            log "SUCCESS" "  brew cu コマンドが利用可能（tap確認）"
        fi
    # アプローチ3: brew commands での確認
    elif brew commands | grep -q "^cu$"; then
        brew_cu_available=true
        log "SUCCESS" "  brew cu コマンドが利用可能（commands で確認）"
    fi
    
    if [[ "$brew_cu_available" == false ]]; then
        log "WARN" "  brew cu が見つかりません"
        log "INFO" "  brew cu は包括的なCaskアップデートを提供します"
        
        # brew-cask-upgradeの自動インストール（公式推奨方法）
        log "INFO" "  brew-cask-upgrade を自動インストール中..."
        if [[ "${DRY_RUN}" == false ]]; then
            echo "  buo/cask-upgrade tap の追加中..."
            if brew tap buo/cask-upgrade; then
                # インストール後の確認
                if brew cu --help >/dev/null 2>&1; then
                    log "SUCCESS" "  brew cu コマンドのインストールが完了"
                else
                    log "WARN" "  brew cu tap は追加されましたが、コマンドの動作確認に失敗"
                fi
            else
                log "WARN" "  buo/cask-upgrade tap の追加に失敗しました（標準コマンドを使用）"
            fi
        else
            log "INFO" "[DRY-RUN] brew tap buo/cask-upgrade"
        fi
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
    
    log "SUCCESS" "✅ 依存関係チェック完了"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}



confirm_execution() {
    if [[ "${DRY_RUN}" == true ]]; then
        return 0  # Dry-runモードでは確認不要
    fi
    
    echo
    log "WARN" "⚠️  実際にHomebrew更新を実行します"
    echo
    echo "📋 実行予定の操作："
    echo "  1. brew update (Homebrewの更新)"
    echo "  2. brew upgrade (formulaeの更新)"
    
    # brew cuの可用性をチェック（実行時と同じロジック）
    local brew_cu_available_prompt=false
    if brew cu --help >/dev/null 2>&1; then
        brew_cu_available_prompt=true
    elif brew tap | grep -q "buo/cask-upgrade"; then
        if brew cu --version >/dev/null 2>&1 || brew cu 2>&1 | grep -q "Usage:"; then
            brew_cu_available_prompt=true
        fi
    elif brew commands | grep -q "^cu$"; then
        brew_cu_available_prompt=true
    fi
    
    if [[ "$brew_cu_available_prompt" == true ]]; then
        echo "  3. brew cu -f -a (包括的cask更新)"
        echo "  4. brew cleanup (キャッシュクリア)"
        echo "  5. Dock差分確認と復元"
    else
        echo "  3. brew-cask-upgrade 自動インストール"
        echo "  4. brew upgrade --cask --greedy (標準cask更新)"
        echo "  5. brew cleanup (キャッシュクリア)"
        echo "  6. Dock差分確認と復元"
    fi
    echo
    echo "⏱️  実行時間の目安: 5-15分（インストール済みパッケージ数による）"
    echo
    echo "🎯 選択肢："
    echo "  [y] はい、実行します"
    echo "  [n] いいえ、キャンセルします（デフォルト）"
    echo "  [d] テスト実行を行います（--dry-run）"
    echo
    
    local response
    read -p "選択してください [y/n/d]: " response
    case "$response" in
        [yY]|[yY][eE][sS])
            log "SUCCESS" "✅ 実行を開始します"
            return 0
            ;;
        [dD])
            log "INFO" "🧪 テスト実行に切り替えます"
            DRY_RUN=true
            return 0
            ;;
        *)
            EXECUTION_STATUS="execution_cancelled"
            log "INFO" "❌ 実行をキャンセルしました"
            echo
            echo "💡 次回は以下のオプションをお試しください："
            echo "  • テスト実行: $(basename "$0") --dry-run"
            echo "  • 詳細出力: $(basename "$0") --verbose"
            echo "  • ヘルプ表示: $(basename "$0") --help"
            exit 0
            ;;
    esac
}

perform_updates() {
    log "INFO" "🚀 Homebrew更新プロセスを開始"
    
    if [[ "${DRY_RUN}" == false ]]; then
        log "INFO" "実際の更新を実行します（変更が行われます）"
        # 実行前の確認
        confirm_execution
        
        # 一時ファイルでDock状態を管理
        local before_dock_file="/tmp/dockeeper_before_$$"
        local after_dock_file="/tmp/dockeeper_after_$$"
        
        # アップデート前のDock状態を保存
        log "INFO" "アップデート前のDock状態を記録中..."
        if ! dockutil --list > "$before_dock_file" 2>/dev/null; then
            log "WARN" "Dock状態の記録に失敗しました"
            touch "$before_dock_file"  # 空ファイルを作成
        fi
        
        # Homebrewアップデート
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log "INFO" "📦 brew update 実行中..."
        if ! brew update; then
            log "WARN" "brew update で警告が発生しました"
        else
            log "SUCCESS" "brew update 完了"
        fi
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log "INFO" "⬆️  brew upgrade (formulae) 実行中..."
        if ! brew upgrade; then
            log "WARN" "brew upgrade で警告が発生しました"
        else
            log "SUCCESS" "brew upgrade (formulae) 完了"
        fi
        
        # Caskアップデート: brew cu を優先使用
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # brew cuの可用性をチェック（依存関係チェックと同じロジック）
        local brew_cu_available=false
        if brew cu --help >/dev/null 2>&1; then
            brew_cu_available=true
        elif brew tap | grep -q "buo/cask-upgrade"; then
            if brew cu --version >/dev/null 2>&1 || brew cu 2>&1 | grep -q "Usage:"; then
                brew_cu_available=true
            fi
        elif brew commands | grep -q "^cu$"; then
            brew_cu_available=true
        fi
        
        if [[ "$brew_cu_available" == true ]]; then
            log "INFO" "🍺 brew cu -f -a (包括的cask upgrade) 実行中..."
            
            # タイムアウトコマンドの利用可能性チェック（macOS互換性向上）
            local timeout_cmd=""
            if command -v gtimeout >/dev/null 2>&1; then
                timeout_cmd="gtimeout 1800"
                log "INFO" "  gtimeout を使用してタイムアウト制御（30分）"
            elif command -v timeout >/dev/null 2>&1; then
                timeout_cmd="timeout 1800"
                log "INFO" "  timeout を使用してタイムアウト制御（30分）"
            else
                log "INFO" "  タイムアウト制御なしで実行（Ctrl+Cで中断可能）"
            fi
            
            # brew cu実行（yes応答付き）
            local brew_cu_cmd="yes | brew cu -f -a"
            if [[ -n "$timeout_cmd" ]]; then
                if ! $timeout_cmd bash -c "$brew_cu_cmd"; then
                    log "WARN" "brew cu で警告が発生またはタイムアウトしました"
                    
                    # brew cu が失敗した場合のフォールバック
                    log "INFO" "標準コマンドでCaskアップデートを試行します..."
                    if ! brew upgrade --cask --greedy; then
                        log "WARN" "brew upgrade --cask でも警告が発生しました"
                    fi
                else
                    log "SUCCESS" "brew cu による包括的なCaskアップデートが完了"
                fi
            else
                if ! bash -c "$brew_cu_cmd"; then
                    log "WARN" "brew cu で警告が発生しました"
                    
                    # brew cu が失敗した場合のフォールバック
                    log "INFO" "標準コマンドでCaskアップデートを試行します..."
                    if ! brew upgrade --cask --greedy; then
                        log "WARN" "brew upgrade --cask でも警告が発生しました"
                    fi
                else
                    log "SUCCESS" "brew cu による包括的なCaskアップデートが完了"
                fi
            fi
        else
            log "INFO" "🍺 brew upgrade --cask --greedy (標準cask upgrade) 実行中..."
            if ! brew upgrade --cask --greedy; then
                log "WARN" "brew upgrade --cask で警告が発生しました"
            else
                log "SUCCESS" "brew upgrade --cask 完了"
            fi
        fi
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log "INFO" "🧹 brew cleanup 実行中..."
        if ! brew cleanup; then
            log "WARN" "brew cleanup で警告が発生しました"
        else
            log "SUCCESS" "brew cleanup 完了"
        fi
        
        # アップデート後のDock状態を取得
        log "INFO" "アップデート後のDock状態を確認中..."
        if ! dockutil --list > "$after_dock_file" 2>/dev/null; then
            log "WARN" "更新後のDock状態取得に失敗しました"
            touch "$after_dock_file"  # 空ファイルを作成
        fi
        
        # 差分検出と復元
        restore_dock_items "$before_dock_file" "$after_dock_file"
        
        # 実行成功ステータス設定
        EXECUTION_STATUS="execution_success"
        
    else
        log "INFO" "🧪 DRY-RUN モード: 実行予定の操作を表示"
        log "INFO" "[DRY-RUN] 以下の操作を実行する予定:"
        log "INFO" "[DRY-RUN]   1. 実行前確認プロンプト"
        log "INFO" "[DRY-RUN]   2. brew update"
        log "INFO" "[DRY-RUN]   3. brew upgrade (formulae)"  
        
        # brew cuの可用性を再チェック（DRY-RUN用）
        local brew_cu_available_dryrun=false
        if brew cu --help >/dev/null 2>&1; then
            brew_cu_available_dryrun=true
        elif brew tap | grep -q "buo/cask-upgrade"; then
            if brew cu --version >/dev/null 2>&1 || brew cu 2>&1 | grep -q "Usage:"; then
                brew_cu_available_dryrun=true
            fi
        elif brew commands | grep -q "^cu$"; then
            brew_cu_available_dryrun=true
        fi
        
        if [[ "$brew_cu_available_dryrun" == true ]]; then
            log "INFO" "[DRY-RUN]   4. brew cu -f -a (包括的cask upgrade)"
            log "INFO" "[DRY-RUN]   5. brew cleanup"
            log "INFO" "[DRY-RUN]   6. Dock差分確認と復元"
        else
            log "INFO" "[DRY-RUN]   4. brew tap buo/cask-upgrade (必要に応じて自動インストール)"
            log "INFO" "[DRY-RUN]   5. brew upgrade --cask --greedy (標準cask upgrade)"
            log "INFO" "[DRY-RUN]   6. brew cleanup"
            log "INFO" "[DRY-RUN]   7. Dock差分確認と復元"
        fi
        
        # Dry-runでのDock状態確認
        log "INFO" "[DRY-RUN] 現在のDock状態を確認中..."
        local dock_count
                 dock_count=$(dockutil --list 2>/dev/null | wc -l || echo "0")
         log "INFO" "[DRY-RUN] 現在のDockアイテム数: $dock_count"
         
                 # Dry-run成功ステータス設定
        EXECUTION_STATUS="dry_run_success"
        log "SUCCESS" "✅ DRY-RUN 実行が完了しました"
    fi
}

restore_dock_items() {
    local before_dock_file="$1"
    local after_dock_file="$2"
    
    # ファイルから配列に読み込み（bash 3.x 互換）
    local before_dock=()
    local after_dock=()
    
    if [[ -f "$before_dock_file" ]]; then
        while IFS= read -r line; do
            before_dock+=("$line")
        done < "$before_dock_file"
    else
        log "WARN" "更新前Dock状態ファイルが見つかりません: $before_dock_file"
        return 1
    fi
    
    if [[ -f "$after_dock_file" ]]; then
        while IFS= read -r line; do
            after_dock+=("$line")
        done < "$after_dock_file"
    else
        log "WARN" "更新後Dock状態ファイルが見つかりません: $after_dock_file"
        return 1
    fi
    
    # アプリ名のみを抽出（dockutilの出力形式から）
    local before_apps=()
    local after_apps=()
    
    for item in "${before_dock[@]}"; do
        if [[ -n "$item" ]]; then
            # dockutil --list の形式: "App Name	file:///Applications/App Name.app/	"
            local app_name
            app_name=$(echo "$item" | cut -f1)
            [[ -n "$app_name" ]] && before_apps+=("$app_name")
        fi
    done
    
    for item in "${after_dock[@]}"; do
        if [[ -n "$item" ]]; then
            local app_name
            app_name=$(echo "$item" | cut -f1)
            [[ -n "$app_name" ]] && after_apps+=("$app_name")
        fi
    done
    
    # 消失したアプリの検出
    local to_restore=()
    for app in "${before_apps[@]}"; do
        if [[ -n "$app" ]] && ! printf '%s\n' "${after_apps[@]}" | grep -Fxq -- "$app"; then
            to_restore+=("$app")
        fi
    done
    
    # 復元処理
    if [[ ${#to_restore[@]} -gt 0 ]]; then
        log "INFO" "${#to_restore[@]} 個のアプリがDockから消失しました"
        [[ "${VERBOSE}" == true ]] && printf "  消失アプリ: %s\n" "${to_restore[@]}"
        
        if [[ "${DRY_RUN}" == false ]]; then
            log "INFO" "Dock復元を開始中..."
            for ((i=0; i<${#to_restore[@]}; i++)); do
                local app="${to_restore[i]}"
                progress_bar $((i+1)) ${#to_restore[@]}
                
                # アプリのパスを検索
                local app_path
                app_path=$(find /Applications -name "${app}.app" -type d 2>/dev/null | head -n1)
                
                if [[ -n "$app_path" ]]; then
                    if dockutil --add "$app_path" --no-restart 2>/dev/null; then
                        [[ "${VERBOSE}" == true ]] && log "SUCCESS" "復元完了: $app"
                    else
                        log "WARN" "復元失敗: $app"
                    fi
                else
                    log "WARN" "アプリが見つかりません: $app (スキップ)"
                fi
            done
            
            echo # プログレスバー後の改行
            
            log "INFO" "Dockを再起動中..."
            killall Dock 2>/dev/null || log "WARN" "Dock再起動に失敗"
            
            APPS_RESTORED_COUNT=${#to_restore[@]}
            log "SUCCESS" "Dock復元処理が完了しました: ${#to_restore[@]} 個のアプリを処理"
        else
            log "INFO" "[DRY-RUN] 以下のアプリを復元する予定:"
            for app in "${to_restore[@]}"; do
                log "INFO" "[DRY-RUN]   - $app"
            done
        fi
    else
        log "SUCCESS" "Dockアイテムの復元は不要です"
    fi
    
    # 一時ファイルの削除
    rm -f "$before_dock_file" "$after_dock_file" 2>/dev/null || true
}

# グローバル変数でステータス追跡
EXECUTION_STATUS="unknown"
APPS_UPDATED_COUNT=0
APPS_RESTORED_COUNT=0

cleanup() {
    # 重複実行を防ぐ
    if [[ "${CLEANUP_EXECUTED:-false}" == "true" ]]; then
        return 0
    fi
    CLEANUP_EXECUTED=true
    
    echo
    case "$EXECUTION_STATUS" in
        "dry_run_success")
            log "SUCCESS" "✅ Dry-run 実行が完了しました"
            echo
            echo "📋 実行結果サマリー:"
            echo "  • モード: テスト実行 (変更なし)"
            echo "  • 現在のDockアイテム数: $(dockutil --list 2>/dev/null | wc -l || echo '0')"
            echo
            echo "💡 次のステップ:"
            echo "  • 実際に実行: $(basename "$0")"
            echo "  • 詳細出力: $(basename "$0") -v"
            ;;
        "execution_success")
            log "SUCCESS" "✅ DocKeeper 実行が正常完了しました"
            echo
                         echo "📋 実行結果サマリー:"
             echo "  • Homebrew更新: 完了"
             echo "  • Dock復元: $APPS_RESTORED_COUNT 個のアプリを処理"
            ;;
        "execution_cancelled")
            log "INFO" "📋 実行がキャンセルされました"
            echo
            echo "💡 お試しオプション:"
            echo "  • テスト実行: $(basename "$0") --dry-run"
            echo "  • ヘルプ表示: $(basename "$0") --help"
            ;;
                 "execution_error")
             log "ERROR" "❌ エラーが発生して終了しました"
             ;;
        *)
            log "INFO" "📋 ${SCRIPT_NAME} 実行完了"
            ;;
    esac
    
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "INFO" "${SCRIPT_NAME} v${VERSION} 終了"
}

main() {
    parse_args "$@"
    setup_environment
    check_and_install_dependencies
    perform_updates
    # cleanup()はtrap 'cleanup' EXITで自動実行される
}

# エラーハンドリング
error_handler() {
    local exit_code=$?
    local line_number=$1
    
    EXECUTION_STATUS="execution_error"
    echo
    log "ERROR" "❌ スクリプトが予期せずに終了しました"
    log "ERROR" "   Exit Code: $exit_code"
    log "ERROR" "   Line: $line_number"
    
    # 一時ファイルのクリーンアップ
    rm -f /tmp/dockeeper_before_$$ /tmp/dockeeper_after_$$ 2>/dev/null || true
    
    echo
    echo "🔧 トラブルシューティング:"
    echo "  • Dry-runでテスト: $(basename "$0") --dry-run"
    echo "  • ヘルプ表示: $(basename "$0") --help"
    echo "  • 依存関係確認: brew --version && dockutil --version"
    
    exit $exit_code
}

trap 'error_handler $LINENO' ERR
trap 'cleanup' EXIT

# メイン実行
main "$@"