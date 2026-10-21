#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export CHANNELS_FILE="$ROOT/tests/fixtures/channels"
export JENKINS_ENV="$TMP_DIR/empty.env"
export CURL_MARKER="$TMP_DIR/curl-called"
export PATH="$ROOT/tests/fixtures/bin:$PATH"
unset JENKINS_USER JENKINS_API_TOKEN JENKINS_BASE JENKINS_NOTIFY JENKINS_TRIGGER_BY JOB || true
: > "$JENKINS_ENV"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Refuse to run if PATH could fall through to a real curl or notification binary.
for name in curl osascript terminal-notifier; do
  fixture="$ROOT/tests/fixtures/bin/$name"
  [ -x "$fixture" ] || fail "fixture is not executable: $fixture"
  [ "$(command -v "$name")" = "$fixture" ] || fail "fixture does not own PATH entry: $name"
done

# Syntax-check every script the suite drives.
for script in "$ROOT"/scripts/*.sh "$ROOT/tests/regression.sh" "$ROOT"/tests/fixtures/bin/*; do
  bash -n "$script" || fail "syntax check failed: $script"
done
echo "PASS: shell syntax check for scripts and fixtures"

expect_contains() {
  local text="$1" expected="$2"
  case "$text" in
    *"$expected"*) ;;
    *) fail "expected output to contain: $expected" ;;
  esac
}

expect_not_contains() {
  local text="$1" unexpected="$2"
  case "$text" in
    *"$unexpected"*) fail "output unexpectedly contained: $unexpected" ;;
  esac
}

expect_reject() {
  local label="$1" expected="$2" status=0 output
  shift 2
  output="$("$@" 2>&1)" || status=$?
  [ "$status" -eq 2 ] || fail "$label: expected exit 2, got $status ($output)"
  expect_contains "$output" "$expected"
  echo "PASS: $label"
}

expect_failure() {
  local label="$1" expected="$2" status=0 output
  shift 2
  output="$("$@" 2>&1)" || status=$?
  [ "$status" -eq 1 ] || fail "$label: expected exit 1, got $status ($output)"
  expect_contains "$output" "$expected"
  echo "PASS: $label"
}

printf 'IOS_JOB_CN=ninebot-iOS-v6-Develop\n' > "$TMP_DIR/incomplete.jobs"
expect_reject "missing job registry key cannot fall back to caller environment" "job 登记文件缺少 IOS_JOB_ENTERPRISE" \
  env IOS_JOB_ENTERPRISE=ninebot-iOS-v6-Release bash -c \
  '. "$1/scripts/common.sh"; load_jobs_file "$2" IOS_JOB_ENTERPRISE IOS_JOB_CN' \
  _ "$ROOT" "$TMP_DIR/incomplete.jobs"
printf 'IOS_JOB_ENTERPRISE=v6-Enterprise-2\nIOS_JOB_CN=ninebot-iOS-v6-Develop\nIOS_JOB_EXTRA=unexpected\n' > "$TMP_DIR/extra.jobs"
expect_reject "job registry refuses undeclared keys" "job 登记文件含未声明的键：IOS_JOB_EXTRA" \
  bash -c '. "$1/scripts/common.sh"; load_jobs_file "$2" IOS_JOB_ENTERPRISE IOS_JOB_CN' \
  _ "$ROOT" "$TMP_DIR/extra.jobs"
printf 'IOS_JOB_ENTERPRISE=v6-Enterprise-2\nnot_a_registry_line\n' > "$TMP_DIR/malformed.jobs"
expect_reject "job registry rejects malformed lines" "job 登记文件格式错误：not_a_registry_line" \
  bash -c '. "$1/scripts/common.sh"; load_jobs_file "$2" IOS_JOB_ENTERPRISE' \
  _ "$ROOT" "$TMP_DIR/malformed.jobs"

output="$(bash "$ROOT/scripts/ios.sh" channels)"
expect_contains "$output" "https://example.invalid/ios-cn"
expect_contains "$output" "https://example.invalid/ios-os"
expect_contains "$output" "密码不直接展示"
expect_contains "$output" "ios.sh channels password"
expect_not_contains "$output" "test-ios-cn-password"
echo "PASS: iOS channels hide passwords by default"

output="$(bash "$ROOT/scripts/ios.sh" channels password)"
expect_contains "$output" "test-ios-cn-password"
expect_contains "$output" "test-ios-os-password"
echo "PASS: iOS channels show passwords only when requested"

output="$(bash "$ROOT/scripts/android.sh" channels)"
expect_contains "$output" "https://example.invalid/android-cn"
expect_contains "$output" "android.sh channels password"
expect_not_contains "$output" "test-android-cn-password"
echo "PASS: Android channels hide passwords by default"

output="$(bash "$ROOT/scripts/jenkins_build.sh" android channels)"
expect_contains "$output" "https://example.invalid/android-cn"
echo "PASS: legacy entry still routes Android channels"

expect_reject "reject extra iOS channel arguments" "channels 参数过多" \
  bash "$ROOT/scripts/ios.sh" channels password extra
expect_reject "reject extra Android channel arguments" "channels 最多接受 password" \
  bash "$ROOT/scripts/android.sh" channels password extra
expect_reject "reject extra daily arguments" "daily 不接受参数" \
  bash "$ROOT/scripts/ios.sh" daily extra
expect_reject "reject extra Android daily arguments" "daily 不接受参数" \
  bash "$ROOT/scripts/android.sh" daily extra
expect_reject "reject extra status arguments" "status 最多接受一个构建号" \
  bash "$ROOT/scripts/ios.sh" status 2040 extra
expect_reject "reject extra latest arguments" "latest 不接受参数" \
  bash "$ROOT/scripts/ios.sh" latest extra
expect_reject "reject extra cancel arguments" "cancel 最多接受一个排队号" \
  bash "$ROOT/scripts/ios.sh" cancel 123 extra
expect_reject "reject extra log arguments" "log 最多接受构建号和行数" \
  bash "$ROOT/scripts/ios.sh" log 2040 10 extra
expect_reject "reject extra jobs arguments" "jobs 不接受参数" \
  bash "$ROOT/scripts/ios.sh" jobs extra
expect_reject "validate status build number before network access" "构建号必须是数字" \
  bash "$ROOT/scripts/ios.sh" status latest
expect_reject "reject malformed wait-build input before network access" "构建号必须是数字" \
  bash "$ROOT/scripts/ios.sh" wait-build abc
expect_reject "reject extra wait-build arguments" "wait-build 参数过多" \
  bash "$ROOT/scripts/ios.sh" wait-build 2040 extra
expect_reject "require explicit trigger confirmation" "先向用户复述 job" \
  bash "$ROOT/scripts/ios.sh" trigger 6.10.12
expect_reject "accept documented extension parameters" "先向用户复述 job" \
  bash "$ROOT/scripts/ios.sh" trigger 6.10.12 RNProjectBranch=feature
expect_reject "force does not replace confirmation" "先向用户复述 job" \
  bash "$ROOT/scripts/ios.sh" trigger 6.10.12 force
expect_reject "restrict Service_Key to test values" "Service_Key=release 需人工在 Jenkins 上触发" \
  bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm Service_Key=release
expect_reject "reject undocumented trigger parameters" "trigger 参数 unknown 不在脚本白名单" \
  bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm unknown=value
expect_reject "reject credential parameters case-insensitively" "参数 Password 禁止由机器人设置" \
  bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm Password=value
expect_reject "reject line breaks in trigger parameters" "参数 branch 不能包含换行符" \
  bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm $'branch=develop\nother=value'
expect_reject "reject control characters in trigger parameters" "参数 branch 不能包含控制字符" \
  bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm $'branch=develop\tspoof'
expect_reject "reject invalid iOS upload switch" "needUpload 只接受 Yes 或 No" \
  bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm needUpload=maybe
expect_reject "reject invalid iOS watermark switch" "watermark 只接受 true 或 false" \
  bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm watermark=maybe
expect_reject "reject missing queue id" "wait-build queue 需要排队号" \
  bash "$ROOT/scripts/ios.sh" wait-build queue
expect_reject "reject nonnumeric queue id" "排队号必须是数字" \
  bash "$ROOT/scripts/ios.sh" wait-build queue abc
expect_reject "reject release job before network access" "JOB=ninebot-iOS-v6-Release 不在白名单" \
  env JOB=ninebot-iOS-v6-Release bash "$ROOT/scripts/ios.sh" status
expect_reject "reject alternate Jenkins base before network access" "脚本只连接 https://jenkins-ios.ninebot.com" \
  env JENKINS_BASE=https://example.invalid bash "$ROOT/scripts/ios.sh" status
expect_reject "Android trigger is left to humans" "Android 打包由人工在 Jenkins 上触发" \
  bash "$ROOT/scripts/android.sh" trigger 6.10.13 confirm
expect_reject "reject Android job outside allow-list" "JOB=ninebot-android-国内-v6-release 不在白名单" \
  env JOB=ninebot-android-国内-v6-release bash "$ROOT/scripts/android.sh" status
expect_reject "reject alternate Android Jenkins base" "脚本只连接 https://jenkins.ninebot.com" \
  env JENKINS_BASE=https://example.invalid bash "$ROOT/scripts/android.sh" status
expect_reject "iOS alias cn resolves to the query-only daily job" "JOB=ninebot-iOS-v6-Develop 不能由机器人触发" \
  env JOB=cn bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm
expect_reject "iOS alias os resolves to the overseas daily job" "JOB=ninebot-iOS-v6-Develop-Overseas 不能由机器人触发" \
  env JOB=海外 bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm
expect_reject "Android alias os resolves before the allow-list check" "缺少凭据" \
  env JOB=os bash "$ROOT/scripts/android.sh" status
expect_reject "Harmony alias agc keeps trigger scope" "提交 AGC 邀请测试审核" \
  env JOB=agc bash "$ROOT/scripts/harmony.sh" trigger 6.10.13
expect_reject "reject Harmony channel commands" "鸿蒙没有每日包渠道" \
  bash "$ROOT/scripts/harmony.sh" channels
expect_reject "reject Harmony job outside allow-list" "JOB=apk-encrypt-v6 不在白名单" \
  env JOB=apk-encrypt-v6 bash "$ROOT/scripts/harmony.sh" status
expect_reject "reject Harmony trigger on query-only job" "JOB=ninebot-hap 不能由机器人触发" \
  env JOB=ninebot-hap bash "$ROOT/scripts/harmony.sh" trigger 6.10.13 confirm
expect_reject "reject alternate Harmony Jenkins base" "脚本只连接 https://jenkins.ninebot.com" \
  env JENKINS_BASE=https://example.invalid bash "$ROOT/scripts/harmony.sh" status
expect_reject "require explicit Harmony trigger confirmation" "提交 AGC 邀请测试审核" \
  bash "$ROOT/scripts/harmony.sh" trigger 6.10.13
expect_reject "Harmony trigger needs a version" "trigger 需要版本号" \
  bash "$ROOT/scripts/harmony.sh" trigger confirm
expect_reject "restrict Harmony products to the test environment" "products=online-prod 需人工在 Jenkins 上触发" \
  bash "$ROOT/scripts/harmony.sh" trigger 6.10.13 confirm products=online-prod
expect_reject "restrict Harmony distribute_mode to test-only" "distribute_mode=2 需人工在 Jenkins 上触发" \
  bash "$ROOT/scripts/harmony.sh" trigger 6.10.13 confirm distribute_mode=2
expect_reject "validate Harmony build_version digits" "build_version 必须是 1-4 位数字" \
  bash "$ROOT/scripts/harmony.sh" trigger 6.10.13 confirm build_version=12345
expect_reject "reject undocumented Harmony trigger parameters" "trigger 参数 Service_Key 不在脚本白名单" \
  bash "$ROOT/scripts/harmony.sh" trigger 6.10.13 confirm Service_Key=test
expect_reject "reject Harmony credential parameters case-insensitively" "参数 PASSWORD 禁止由机器人设置" \
  bash "$ROOT/scripts/harmony.sh" trigger 6.10.13 confirm PASSWORD=x
expect_reject "reject line breaks in Harmony trigger parameters" "参数 app_desc 不能包含换行符" \
  bash "$ROOT/scripts/harmony.sh" trigger 6.10.13 confirm $'app_desc=a\nb'
expect_reject "reject invalid Harmony submission switch" "auto_submit 只接受 true 或 false" \
  bash "$ROOT/scripts/harmony.sh" trigger 6.10.13 confirm auto_submit=maybe

if [ -e "$CURL_MARKER" ]; then
  fail "a guarded local command attempted to call curl"
fi
echo "PASS: guard-path regression cases made no network calls"

# All calls below use the local curl fixture and synthetic credentials.
unset CURL_MARKER
export MOCK_CALLS_FILE="$TMP_DIR/calls"
export AUDIT_FILE="$TMP_DIR/audit.log"
export JENKINS_USER=fixture JENKINS_API_TOKEN=fixture JENKINS_BASE=https://jenkins-ios.ninebot.com
export MOCK_SCENARIO=success

output="$(bash "$ROOT/scripts/ios.sh" status 2040)"
expect_contains "$output" "状态: SUCCESS"
expect_contains "$output" "耗时: 16.0 分钟"
expect_not_contains "$output" "失败分析"
echo "PASS: successful build status"

output="$(MOCK_SCENARIO=pending bash "$ROOT/scripts/ios.sh" status 2040)"
expect_contains "$output" "状态: UNKNOWN"
expect_not_contains "$output" "失败分析"
echo "PASS: result-null status is not diagnosed as a failure"

output="$(MOCK_SCENARIO=building_status bash "$ROOT/scripts/ios.sh" status 2056)"
expect_contains "$output" "状态: 构建中"
echo "PASS: a failed optional queue ETA does not hide build status"

output="$(bash "$ROOT/scripts/ios.sh" status 2041)"
expect_contains "$output" "状态: FAILURE"
expect_contains "$output" "失败步骤"
expect_contains "$output" "fatal error: compile failed"
expect_contains "$output" "Alice: Fix build"
expect_not_contains "$output" "secret-value"
output="$(MOCK_SCENARIO=console_error bash "$ROOT/scripts/ios.sh" status 2041)"
expect_contains "$output" "状态: FAILURE"
expect_contains "$output" "失败分析：控制台暂不可用。构建页："
echo "PASS: failure summary redacts console and changeSet secrets"

output="$(bash "$ROOT/scripts/ios.sh" log 2041 10)"
expect_not_contains "$output" "secret-value"
expect_contains "$output" "fatal error: compile failed"
echo "PASS: console log redaction"

output="$(bash "$ROOT/scripts/ios.sh" latest)"
expect_contains "$output" "最近成功构建：#2040"
expect_contains "$output" "蒲公英下载：https://www.pgyer.com/fixture"
expect_contains "$output" "短链接：https://www.pgyer.com/fixture-short"
expect_contains "$output" "版本号：6.10.12.2040"
expect_not_contains "$output" "构建编号"
expect_not_contains "$output" "build号"
output="$(MOCK_SCENARIO=no_link bash "$ROOT/scripts/ios.sh" latest)"
expect_contains "$output" "控制台未提取到蒲公英链接。构建页："
expect_not_contains "$output" "版本号："
output="$(MOCK_SCENARIO=artifact_only bash "$ROOT/scripts/ios.sh" latest)"
expect_contains "$output" "蒲公英：控制台无上传记录"
expect_contains "$output" "产物：Ninebot_mainland_develop_test_v6.10.12(2040)_20261020_1838.ipa"
expect_contains "$output" "Jenkins 产物下载（需登录）：https://jenkins-ios.ninebot.com/job/v6-Enterprise-2/2040/artifact/ios/ipa/Ninebot_mainland_develop_test_v6.10.12(2040)_20261020_1838.ipa"
expect_contains "$output" "版本号：6.10.12.2040"
expect_not_contains "$output" "构建页："
expect_not_contains "$output" "build.log"
output="$(MOCK_SCENARIO=console_error bash "$ROOT/scripts/ios.sh" latest)"
expect_contains "$output" "最近成功构建：#2040"
expect_contains "$output" "产物信息暂不可用。构建页："
output="$(MOCK_SCENARIO=console_error_with_artifact bash "$ROOT/scripts/ios.sh" latest)"
expect_contains "$output" "蒲公英：控制台暂不可用，改给 Jenkins 归档产物"
expect_contains "$output" "Jenkins 产物下载（需登录）："
echo "PASS: latest build link, app version/build number, artifact fallback and missing-link fallback"

output="$(bash "$ROOT/scripts/ios.sh" wait-build 2040)"
expect_contains "$output" "构建 #2040"
expect_contains "$output" "状态: SUCCESS"
expect_contains "$output" "蒲公英下载："
expect_contains "$output" "版本号：6.10.12.2040"
expect_not_contains "$output" "失败分析"
output="$(bash "$ROOT/scripts/ios.sh" wait-build 2041)"
expect_contains "$output" "状态: FAILURE"
expect_contains "$output" "失败分析"
expect_not_contains "$output" "蒲公英下载："
expect_not_contains "$output" "secret-value"
output="$(bash "$ROOT/scripts/ios.sh" wait-build queue 78)"
expect_contains "$output" "构建 #2040"
expect_contains "$output" "状态: SUCCESS"
echo "PASS: explicit build and expired queue id bind to the right build"

# ---- 本机 macOS 通知（JENKINS_NOTIFY=1；osascript/terminal-notifier 都打到 stub）----
export NOTIFY_CALLS_FILE="$TMP_DIR/notify"
: > "$NOTIFY_CALLS_FILE"
output="$(bash "$ROOT/scripts/ios.sh" wait-build 2040)"
[ ! -s "$NOTIFY_CALLS_FILE" ] || fail "local notification fired without JENKINS_NOTIFY=1"
output="$(JENKINS_NOTIFY=1 bash "$ROOT/scripts/ios.sh" wait-build 2040)"
expect_contains "$output" "状态: SUCCESS"
grep -q "构建 #2040 · SUCCESS · 耗时 16.0 分钟 · 6.10.12.2040" "$NOTIFY_CALLS_FILE" \
  || fail "success notification body mismatch: $(cat "$NOTIFY_CALLS_FILE")"
grep -q "terminal-notifier .*-open https://www.pgyer.com/fixture" "$NOTIFY_CALLS_FILE" \
  || fail "success notification should open the artifact link"
: > "$NOTIFY_CALLS_FILE"
output="$(JENKINS_NOTIFY=1 bash "$ROOT/scripts/ios.sh" wait-build 2041)"
expect_contains "$output" "状态: FAILURE"
grep -q "构建 #2041 · FAILURE" "$NOTIFY_CALLS_FILE" \
  || fail "failure notification body mismatch: $(cat "$NOTIFY_CALLS_FILE")"
grep -q -- "-sound Basso" "$NOTIFY_CALLS_FILE" \
  || fail "failure notification should use the Basso sound"
: > "$NOTIFY_CALLS_FILE"
output="$(JENKINS_NOTIFY=1 bash "$ROOT/scripts/ios.sh" latest)"
[ ! -s "$NOTIFY_CALLS_FILE" ] || fail "latest should not send a local notification"
unset NOTIFY_CALLS_FILE
echo "PASS: local macOS notification on wait-build only, behind JENKINS_NOTIFY=1"

output="$(MOCK_SCENARIO=queue bash "$ROOT/scripts/ios.sh" wait-build queue 77)"
expect_contains "$output" "等待排队项 77"
expect_contains "$output" "构建 #2040"
expect_contains "$output" "状态: SUCCESS"
output="$(MOCK_SCENARIO=queue bash "$ROOT/scripts/ios.sh" wait-build)"
expect_contains "$output" "构建 #2040"
expect_reject "queued and running builds require an explicit target" "同时有排队项和运行中的构建" \
  env MOCK_SCENARIO=queue_and_running bash "$ROOT/scripts/ios.sh" wait-build
expect_reject "idle wait-build does not use lastBuild" "当前没有进行中的排队或构建" \
  bash "$ROOT/scripts/ios.sh" wait-build
expect_reject "multiple queued builds require an id" "该 job 有多个排队项" \
  env MOCK_SCENARIO=queue_multiple bash "$ROOT/scripts/ios.sh" wait-build
expect_reject "queue API failure stops unbound wait" "无法确认该 job 是否在排队" \
  env MOCK_SCENARIO=query_error bash "$ROOT/scripts/ios.sh" wait-build
expect_reject "result-null build is not reported complete" "等待超时" \
  env MOCK_SCENARIO=pending WAIT_BUILD_MAX_TRIES=1 bash "$ROOT/scripts/ios.sh" wait-build 2040
echo "PASS: queue and wait-build binding guards"

output="$(MOCK_SCENARIO=cancel bash "$ROOT/scripts/ios.sh" cancel)"
expect_contains "$output" "id=77"
output="$(MOCK_SCENARIO=cancel bash "$ROOT/scripts/ios.sh" cancel 77)"
expect_contains "$output" "已取消排队任务"
expect_reject "cancel id must belong to the job queue" "不是 v6-Enterprise-2 的排队项" \
  env MOCK_SCENARIO=cancel bash "$ROOT/scripts/ios.sh" cancel 78
echo "PASS: cancel lists and checks queue ids"

: > "$MOCK_CALLS_FILE"
output="$(JENKINS_TRIGGER_BY=$'qa\nspoof' MOCK_SCENARIO=trigger bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm branch=feature)"
expect_contains "$output" "排队号：77"
expect_contains "$output" "本次构建：#2040"
expect_contains "$output" "触发人：qaspoof"
grep -Fqx 'PARAM branch=feature' "$MOCK_CALLS_FILE" || fail "trigger did not send branch override"
grep -Fqx 'PARAM main_version=6.10.12' "$MOCK_CALLS_FILE" || fail "trigger did not send version"
grep -Fq 'POST /job/v6-Enterprise-2/buildWithParameters' "$MOCK_CALLS_FILE" || fail "trigger did not POST"
[ "$(wc -l < "$AUDIT_FILE" | tr -d ' ')" -eq 1 ] || fail "audit log should contain one line"
grep -Fq 'trigger_by=qaspoof' "$AUDIT_FILE" || fail "audit log did not sanitize trigger by"
echo "PASS: confirmed trigger uses expected parameters and one-line audit"

output="$(MOCK_SCENARIO=trigger_no_location bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm)"
expect_contains "$output" "未返回排队地址；无法绑定本次构建"
expect_contains "$output" "不要直接重试"
echo "PASS: trigger response without a queue location is not bound to a build"

output="$(MOCK_SCENARIO=trigger_other_location bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm)"
expect_contains "$output" "返回的地址不是排队项"
expect_not_contains "$output" "已入队："
echo "PASS: trigger response with a non-queue location is not treated as queued"
expect_failure "transport error after POST has an unknown outcome" "结果不确定" \
  env MOCK_SCENARIO=trigger_transport_error bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm
expect_failure "HTTP error after POST does not invite a blind retry" "结果可能不确定" \
  env MOCK_SCENARIO=trigger_http_error bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm

output="$(AUDIT_FILE="$JENKINS_ENV/audit.log" MOCK_SCENARIO=trigger bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm 2>&1)"
expect_contains "$output" "排队号：77"
expect_contains "$output" "构建已触发，但审计日志写入失败；请勿直接重试触发"
echo "PASS: post-trigger audit failure is visible without suggesting a retry"

: > "$MOCK_CALLS_FILE"
expect_reject "running build blocks unforced trigger" "已有构建进行中或排队中" \
  env MOCK_SCENARIO=running bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm
if grep -Fq 'POST /job/v6-Enterprise-2/buildWithParameters' "$MOCK_CALLS_FILE"; then
  fail "unforced trigger posted during an active build"
fi
output="$(MOCK_SCENARIO=running bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm force)"
expect_contains "$output" "排队号：77"
echo "PASS: force is required for an active build"

: > "$MOCK_CALLS_FILE"
expect_reject "failed queue query blocks trigger" "无法确认该 job 是否已有构建" \
  env MOCK_SCENARIO=query_error bash "$ROOT/scripts/ios.sh" trigger 6.10.12 confirm
if grep -Fq 'POST /job/v6-Enterprise-2/buildWithParameters' "$MOCK_CALLS_FILE"; then
  fail "trigger posted after queue API failure"
fi
echo "PASS: trigger fails closed when the queue cannot be checked"

# ---- HarmonyOS: same contract against the harmony Jenkins fixture ----
export JENKINS_BASE=https://jenkins.ninebot.com
export MOCK_SCENARIO=success

output="$(bash "$ROOT/scripts/harmony.sh" status 343)"
expect_contains "$output" "构建 #343"
expect_contains "$output" "状态: SUCCESS"
expect_contains "$output" "耗时: 14.8 分钟"
expect_not_contains "$output" "失败分析"
echo "PASS: Harmony build status"

output="$(bash "$ROOT/scripts/harmony.sh" latest)"
expect_contains "$output" "最近成功构建：#343"
expect_contains "$output" "邀请测试链接：https://appgallery.huawei.com/apptest/join/fixture"
expect_contains "$output" "versionCode：610131377"
expect_not_contains "$output" "蒲公英"
output="$(MOCK_SCENARIO=no_link bash "$ROOT/scripts/harmony.sh" latest)"
expect_contains "$output" "控制台未提取到邀请测试链接。构建页："
output="$(MOCK_SCENARIO=console_error bash "$ROOT/scripts/harmony.sh" latest)"
expect_contains "$output" "最近成功构建：#343"
expect_contains "$output" "产物信息暂不可用。构建页："
echo "PASS: Harmony latest extracts AGC share link and versionCode, with fallback"

output="$(bash "$ROOT/scripts/harmony.sh" wait-build 343)"
expect_contains "$output" "构建 #343"
expect_contains "$output" "状态: SUCCESS"
expect_contains "$output" "邀请测试链接："
expect_not_contains "$output" "失败分析"
echo "PASS: Harmony wait-build reports AGC artifact info"

: > "$MOCK_CALLS_FILE"
: > "$AUDIT_FILE"
output="$(JENKINS_TRIGGER_BY=qa MOCK_SCENARIO=trigger bash "$ROOT/scripts/harmony.sh" trigger 6.10.13 confirm branch=feat/x rn_branch_name=feat_v1 auto_submit=false)"
expect_contains "$output" "触发构建：JOB=ninebot-harmony-agc main_version=6.10.13"
expect_contains "$output" "本次打包参数："
expect_contains "$output" "products=default-prod"
expect_contains "$output" "distribute_mode=1"
expect_contains "$output" "排队号：77"
expect_contains "$output" "本次构建：#343"
expect_contains "$output" "触发人：qa"
grep -Fqx 'PARAM main_version=6.10.13' "$MOCK_CALLS_FILE" || fail "harmony trigger did not send version"
grep -Fqx 'PARAM branch=feat/x' "$MOCK_CALLS_FILE" || fail "harmony trigger did not send branch override"
grep -Fqx 'PARAM rn_branch_name=feat_v1' "$MOCK_CALLS_FILE" || fail "harmony trigger did not send rn_branch_name"
grep -Fqx 'PARAM auto_submit=false' "$MOCK_CALLS_FILE" || fail "harmony trigger did not send auto_submit override"
grep -Fqx 'PARAM products=default-prod' "$MOCK_CALLS_FILE" || fail "harmony trigger did not send default products"
if grep -Fq 'PARAM build_version=' "$MOCK_CALLS_FILE"; then
  fail "harmony trigger must not send build_version unless given"
fi
grep -Fq 'POST /job/ninebot-harmony-agc/buildWithParameters' "$MOCK_CALLS_FILE" || fail "harmony trigger did not POST"
[ "$(wc -l < "$AUDIT_FILE" | tr -d ' ')" -eq 1 ] || fail "harmony audit log should contain one line"
grep -Fq 'JOB=ninebot-harmony-agc products=default-prod' "$AUDIT_FILE" || fail "harmony audit missing job/products"
echo "PASS: confirmed Harmony trigger sends defaults, overrides and audits once"

: > "$MOCK_CALLS_FILE"
expect_reject "running Harmony build blocks unforced trigger" "已有构建进行中或排队中" \
  env MOCK_SCENARIO=running bash "$ROOT/scripts/harmony.sh" trigger 6.10.13 confirm
if grep -Fq 'POST /job/ninebot-harmony-agc/buildWithParameters' "$MOCK_CALLS_FILE"; then
  fail "unforced harmony trigger posted during an active build"
fi
output="$(MOCK_SCENARIO=running bash "$ROOT/scripts/harmony.sh" trigger 6.10.13 confirm force)"
expect_contains "$output" "排队号：77"
echo "PASS: Harmony force is required for an active build"

# ---- Android: query-only against the main Jenkins fixture ----
export MOCK_SCENARIO=success

output="$(bash "$ROOT/scripts/android.sh" status)"
expect_contains "$output" "构建 #1277"
expect_contains "$output" "状态: SUCCESS"
expect_contains "$output" "耗时: 25.0 分钟"
output="$(env JOB=国内 bash "$ROOT/scripts/android.sh" status 1277)"
expect_contains "$output" "构建 #1277"
echo "PASS: Android status via default and alias"

output="$(bash "$ROOT/scripts/android.sh" latest)"
expect_contains "$output" "最近成功构建：#1277"
expect_contains "$output" "产物：Segway-Ninebot_v6.10.13_domestic_debug_202610201033_ddfe151186_with_so_encrypted.apk"
expect_contains "$output" "蒲公英：本次构建不上传"
expect_not_contains "$output" "蒲公英下载："
output="$(MOCK_SCENARIO=console_error bash "$ROOT/scripts/android.sh" latest)"
expect_contains "$output" "最近成功构建：#1277"
expect_contains "$output" "产物信息暂不可用。构建页："
echo "PASS: Android latest extracts APK name and the no-upload note"

output="$(bash "$ROOT/scripts/android.sh" wait-build 1277)"
expect_contains "$output" "构建 #1277"
expect_contains "$output" "状态: SUCCESS"
expect_contains "$output" "产物："
echo "PASS: Android wait-build reports APK artifact info"

output="$(env JOB=os bash "$ROOT/scripts/android.sh" status)"
expect_contains "$output" "构建 #1895"
expect_contains "$output" "状态: SUCCESS"
expect_contains "$output" "耗时: 52.0 分钟"
output="$(env JOB=海外 bash "$ROOT/scripts/android.sh" latest)"
expect_contains "$output" "最近成功构建：#1895"
expect_contains "$output" "产物：Segway-Ninebot_v6.10.13_overseas_debug_202610191945_ce5ddf9_with_so_encrypted.apk"
expect_contains "$output" "蒲公英：本次构建不上传"
echo "PASS: Android overseas job via alias os/海外"

expect_reject "never-built Android job reports no builds instead of HTTP 404" "该 job 暂无构建记录" \
  env JOB=os MOCK_SCENARIO=no_builds bash "$ROOT/scripts/android.sh" status
expect_reject "never-built Android job has no successful build" "该 job 暂无成功构建" \
  env JOB=os MOCK_SCENARIO=no_builds bash "$ROOT/scripts/android.sh" latest
echo "PASS: 404 from Jenkins is explained for jobs without builds"
