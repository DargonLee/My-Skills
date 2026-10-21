#!/bin/bash
# Android Jenkins (query only). Credentials: <skill>/env/android.env
# Shared HTTP lives in common.sh. Job rules stay here. Trigger is left to humans.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

ANDROID_BASE="https://jenkins.ninebot.com"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${JENKINS_ENV:-$SKILL_DIR/env/android.env}"
EXPECTED_BASE="$ANDROID_BASE"
load_env_file "$ENV_FILE"
load_jobs_file "$SKILL_DIR/platforms/android.jobs" ANDROID_JOB_CN ANDROID_JOB_OS
JENKINS_BASE="${JENKINS_BASE:-$ANDROID_BASE}"

resolve_job() {
  # JOB 可以是登记文件里的 job 名，也可以是别名：cn（默认，国内）/ os（海外）
  case "$1" in
    ''|cn|CN|国内) printf '%s' "$ANDROID_JOB_CN" ;;
    os|OS|overseas|海外) printf '%s' "$ANDROID_JOB_OS" ;;
    *) printf '%s' "$1" ;;
  esac
}
JOB="$(resolve_job "${JOB:-}")"

job_scope() {
  if [ "$1" = "$ANDROID_JOB_CN" ] || [ "$1" = "$ANDROID_JOB_OS" ]; then
    printf 'query'
  else
    printf 'deny'
  fi
}

job_denied_message() {
  printf '%s' "JOB=${JOB} 不在白名单。可查询的只有 ${ANDROID_JOB_CN}（cn）与 ${ANDROID_JOB_OS}（os）"
}

job_trigger_denied_message() {
  printf '%s' "Android 打包由人工在 Jenkins 上触发，机器人只查询（status / latest / log / wait-build / cancel）"
}

base_mismatch_message() {
  printf '%s' "脚本只连接 ${ANDROID_BASE}（Android）。iOS 用 ios.sh，不要修改 JENKINS_BASE"
}

platform_artifact_info() {
  # Android 产物：上传了蒲公英就给链接；否则给最终 APK 文件名（含版本/环境/时间戳/commit）。
  local num="$1" path console pgyer short apk
  path="$(job_path)"
  console="$(mktemp)"
  if ! api_get "/job/${path}/${num}/consoleText" quiet > "$console"; then
    rm -f "$console"
    echo "产物信息暂不可用。构建页：${JENKINS_BASE}/job/${path}/${num}/"
    return 0
  fi
  pgyer="$(grep -oE '应用构建主页：https://www\.pgyer\.com/[^ ]+' "$console" | head -n 1 | sed 's/应用构建主页：//' || true)"
  short="$(grep -oE '应用短链接：[^ ]+' "$console" | head -n 1 | sed 's/应用短链接：//' || true)"
  apk="$(grep -oE 'protected success\. outfile is .*\.apk' "$console" | tail -n 1 | sed 's/.*outfile is //' || true)"
  if [ -z "$apk" ]; then
    apk="$(grep -oE '[^ ]+/outputs/apk/[^ ]+\.apk' "$console" | tail -n 1 || true)"
  fi
  if [ -n "$apk" ]; then
    echo "产物：$(basename "$apk")"
  fi
  if [ -n "$pgyer" ]; then
    echo "蒲公英下载：${pgyer}"
    if [ -n "$short" ]; then
      echo "短链接：https://www.pgyer.com/${short}"
    fi
  elif grep -q '本次构建不上传蒲公英' "$console"; then
    echo "蒲公英：本次构建不上传（isUpload=false），包在打包机上"
  elif [ -z "$apk" ]; then
    echo "控制台未提取到产物信息。构建页：${JENKINS_BASE}/job/${path}/${num}/"
  fi
  rm -f "$console"
}

usage() {
  cat <<'EOF'
用法: android.sh <子命令> [参数]
凭据: env/android.env    job 登记: platforms/android.jobs
JOB 环境变量可用 job 名或别名：cn（默认，国内）/ os（海外）

  channels [password]                  每日包链接（默认不显示密码；password 才输出密码）
  daily                                每日包主动推送检查入口（挂载层每天定时调用）
  status [构建号]                      查询构建状态
  latest                               该 job 最近成功构建和产物信息
  wait-build queue <排队号> | <构建号> | （空）  等待构建结束，合同与 ios.sh 相同
  cancel                               列出该 job 的排队项
  cancel <queue_id>                    取消指定排队项
  log [构建号] [行数]                  控制台尾部（默认 30 行）
  jobs                                 列出可见 job

Android 打包由人工在 Jenkins 上触发；本脚本没有 trigger。
EOF
}

cmd_daily() {
  cmd_channels android
  echo
  echo "每日包更新判断：固定链接始终指向最新上传版本。要确认当日是否有新包，执行 android.sh status（国内）或 JOB=os android.sh status（海外）看最近构建时间。"
}

CMD="${1:-}"
case "$CMD" in
  channels)
    [ "$#" -le 2 ] || die "channels 最多接受 password"
    cmd_channels android "${2:-}"
    ;;
  daily)
    [ "$#" -eq 1 ] || die "daily 不接受参数"
    cmd_daily
    ;;
  trigger) die "$(job_trigger_denied_message)" ;;
  wait-build) shift; cmd_wait_build "$@" ;;
  status)
    [ "$#" -le 2 ] || die "status 最多接受一个构建号"
    shift; cmd_status "$@"
    ;;
  latest)
    [ "$#" -eq 1 ] || die "latest 不接受参数"
    cmd_latest
    ;;
  cancel)
    [ "$#" -le 2 ] || die "cancel 最多接受一个排队号"
    shift; cmd_cancel "$@"
    ;;
  log)
    [ "$#" -le 3 ] || die "log 最多接受构建号和行数"
    shift; cmd_log "$@"
    ;;
  jobs)
    [ "$#" -eq 1 ] || die "jobs 不接受参数"
    cmd_jobs
    ;;
  -h|--help|help) usage; exit 0 ;;
  "") usage; exit 2 ;;
  *) usage; exit 2 ;;
esac
