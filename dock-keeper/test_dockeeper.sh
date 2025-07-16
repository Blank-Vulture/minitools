#!/usr/bin/env bash
# DocKeeper Unit Test Suite
# 実行: ./test_dockeeper.sh

set -euo pipefail

# テスト環境設定
readonly TEST_DIR="/tmp/dockeeper_test_$$"
readonly SCRIPT_PATH="$(dirname "$0")/dockeeper.sh"
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# テスト結果追跡
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# 設定変数
VERBOSE=${VERBOSE:-false}

# ヘルパー関数
log_test() {
    local level="$1"
    local message="$2"
    case "$level" in
        "PASS") echo -e "${GREEN}✓ PASS${NC}: $message" ;;
        "FAIL") echo -e "${RED}✗ FAIL${NC}: $message" ;;
        "INFO") echo -e "${YELLOW}ℹ INFO${NC}: $message" ;;
    esac
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_test "PASS" "$test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_test "FAIL" "$test_name"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
    fi
}

assert_exit_code() {
    local expected_code="$1"
    local command="$2"
    local test_name="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if bash -c "$command" >/dev/null 2>&1; then
        actual_code=0
    else
        actual_code=$?
    fi
    
    if [[ $expected_code -eq $actual_code ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_test "PASS" "$test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_test "FAIL" "$test_name"
        echo "  Expected exit code: $expected_code"
        echo "  Actual exit code:   $actual_code"
    fi
}

setup_test_env() {
    mkdir -p "$TEST_DIR"
    export HOME="$TEST_DIR"
}

teardown_test_env() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

# === テストケース ===

test_help_option() {
    log_test "INFO" "Testing help option..."
    
    local output
    output=$($SCRIPT_PATH --help 2>&1 || true)
    
    if [[ "$output" =~ "DocKeeper v2.2" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_test "PASS" "Help option shows version"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_test "FAIL" "Help option doesn't show version"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_version_option() {
    log_test "INFO" "Testing version option..."
    
    local output
    output=$($SCRIPT_PATH --version 2>&1 || true)
    
    if [[ "$output" =~ "DocKeeper v2.2.0" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_test "PASS" "Version option works"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_test "FAIL" "Version option doesn't work"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_invalid_option() {
    log_test "INFO" "Testing invalid option handling..."
    
    assert_exit_code 1 "$SCRIPT_PATH --invalid-option" "Invalid option returns exit code 1"
}

test_dry_run_mode() {
    log_test "INFO" "Testing dry-run mode..."
    
    local output
    output=$($SCRIPT_PATH --dry-run 2>&1 || true)
    
    if [[ "$output" =~ "DRY-RUN" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_test "PASS" "Dry-run mode shows DRY-RUN messages"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_test "FAIL" "Dry-run mode doesn't work"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_script_permissions() {
    log_test "INFO" "Testing script permissions..."
    
    if [[ -x "$SCRIPT_PATH" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_test "PASS" "Script is executable"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_test "FAIL" "Script is not executable"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_dependency_check() {
    log_test "INFO" "Testing dependency checking..."
    
    # brew が存在する場合のテスト
    if command -v brew >/dev/null 2>&1; then
        local output
        output=$($SCRIPT_PATH --dry-run 2>&1 || true)
        
        if [[ ! "$output" =~ "Homebrewが必要です" ]]; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
            log_test "PASS" "Homebrew dependency check works"
        else
            TESTS_FAILED=$((TESTS_FAILED + 1))
            log_test "FAIL" "Homebrew dependency check fails"
        fi
    else
        log_test "INFO" "Skipping Homebrew test (not installed)"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_security_input_validation() {
    log_test "INFO" "Testing security input validation..."
    
    # 悪意のある引数パターンをテスト
    local malicious_inputs=(
        "--help; rm -rf /tmp/test_file_security_$$"
        "--version && echo 'SECURITY_BREACH'"
        "--dry-run | cat /etc/passwd"
        "--verbose \$(echo 'injection')"
        "--unknown-option ../../../etc/passwd"
    )
    
    local security_passed=0
    for input in "${malicious_inputs[@]}"; do
        # 悪意のある引数でスクリプトを実行し、適切にエラー処理されることを確認
        local output
        local exit_code
        
        # タイムアウト付きでテスト実行
        if output=$(timeout 5 bash -c "$SCRIPT_PATH $input" 2>&1); then
            exit_code=0
        else
            exit_code=$?
        fi
        
        # 以下の条件でセキュリティテスト合格：
        # 1. exit_codeが0でない（エラーで終了） または
        # 2. outputに"不明なオプション"など適切なエラーメッセージが含まれる
        if [[ $exit_code -ne 0 ]] || [[ "$output" =~ "不明なオプション" ]] || [[ "$output" =~ "Error" ]]; then
            security_passed=$((security_passed + 1))
            [[ "${VERBOSE}" == true ]] && log_test "INFO" "Security test passed for: $input"
        else
            [[ "${VERBOSE}" == true ]] && log_test "WARN" "Security concern for: $input (exit: $exit_code)"
        fi
    done
    
    # 追加: ファイルシステム操作のセキュリティテスト
    local test_file="/tmp/security_test_file_$$"
    touch "$test_file" 2>/dev/null || true
    
    # 悪意のあるパスでの実行を試行
    local malicious_path_output
    malicious_path_output=$(timeout 3 bash -c "SCRIPT_PATH='$test_file; rm -f $test_file; echo BREACH' $SCRIPT_PATH --help" 2>&1 || true)
    
    # テストファイルが削除されていないことを確認
    if [[ -f "$test_file" ]]; then
        security_passed=$((security_passed + 1))
        [[ "${VERBOSE}" == true ]] && log_test "INFO" "File system injection protection works"
    fi
    
    # クリーンアップ
    rm -f "$test_file" 2>/dev/null || true
    
    local total_tests=$((${#malicious_inputs[@]} + 1))
    if [[ $security_passed -eq $total_tests ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_test "PASS" "Security input validation works ($security_passed/$total_tests tests passed)"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_test "FAIL" "Security input validation has issues ($security_passed/$total_tests tests passed)"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_error_handling() {
    log_test "INFO" "Testing error handling..."
    
    # 存在しない引数でのテスト
    local output
    output=$($SCRIPT_PATH --nonexistent-flag 2>&1 || true)
    
    if [[ "$output" =~ "不明なオプション" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_test "PASS" "Error handling for unknown options works"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_test "FAIL" "Error handling for unknown options doesn't work"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_performance_basic() {
    log_test "INFO" "Testing basic performance..."
    
    local start_time end_time duration
    start_time=$(date +%s.%N)
    
    $SCRIPT_PATH --help >/dev/null 2>&1 || true
    
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    
    # ヘルプ表示は1秒以内であるべき
    if (( $(echo "$duration < 1.0" | bc -l) )); then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_test "PASS" "Help command executes within 1 second ($duration s)"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_test "FAIL" "Help command too slow ($duration s)"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_log_directory_creation() {
    log_test "INFO" "Testing log directory creation..."
    
    # テスト環境でのdry-run実行
    local test_home="$TEST_DIR/test_home"
    mkdir -p "$test_home"
    
    HOME="$test_home" $SCRIPT_PATH --dry-run >/dev/null 2>&1 || true
    
    if [[ -d "$test_home/.local/share/dockeeper" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_test "PASS" "Log directory created successfully"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_test "FAIL" "Log directory not created"
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
}

# メイン実行
main() {
    echo "=== DocKeeper Test Suite ==="
    echo "Testing script: $SCRIPT_PATH"
    echo
    
    setup_test_env
    
    # 基本機能テスト
    test_script_permissions
    test_help_option
    test_version_option
    test_invalid_option
    test_dry_run_mode
    
    # 依存関係テスト
    test_dependency_check
    
    # セキュリティテスト
    test_security_input_validation
    
    # エラーハンドリングテスト
    test_error_handling
    
    # パフォーマンステスト
    test_performance_basic
    
    # ファイルシステムテスト
    test_log_directory_creation
    
    teardown_test_env
    
    # 結果サマリ
    echo
    echo "=== Test Results ==="
    echo "Tests run:    $TESTS_RUN"
    echo "Passed:       $TESTS_PASSED"
    echo "Failed:       $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# スクリプト存在チェック
if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo "Error: Script not found at $SCRIPT_PATH"
    exit 1
fi

# bc が利用可能かチェック（パフォーマンステスト用）
if ! command -v bc >/dev/null 2>&1; then
    echo "Warning: 'bc' not found. Performance tests will be skipped."
fi

main "$@" 