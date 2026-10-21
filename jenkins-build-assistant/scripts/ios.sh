#!/bin/bash
# iOS Jenkins. Credentials: <skill>/env/ios.env
# Shared HTTP lives in common.sh. Job rules and parameters stay here.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

IOS_BASE="https://jenkins-ios.ninebot.com"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${JENKINS_ENV:-$SKILL_DIR/env/ios.env}"
EXPECTED_BASE="$IOS_BASE"
load_env_file "$ENV_FILE"
load_jobs_file "$SKILL_DIR/platforms/ios.jobs" IOS_JOB_ENTERPRISE IOS_JOB_CN IOS_JOB_OS
JENKINS_BASE="${JENKINS_BASE:-$IOS_BASE}"

resolve_job() {
  # JOB 可以是登记文件里的 job 名，也可以是别名：enterprise / cn（国内）/ os（海外）
  case "$1" in
    ''|enterprise|ent|企业签) printf '%s' "$IOS_JOB_ENTERPRISE" ;;
    cn|CN|国内) printf '%s' "$IOS_JOB_CN" ;;
    os|OS|overseas|海外) printf '%s' "$IOS_JOB_OS" ;;
    *) printf '%s' "$1" ;;
  esac
}
JOB="$(resolve_job "${JOB:-}")"

# Defaults match platforms/ios.md. Allow-list matches platforms/ios.jobs.
PARAMS="$(cat <<'EOF'
Service_Key=test
branch=develop
env=国内
BuildConfiguration=Debug
channel=Release
Confusion=无
Xcode=26
needUpload=No
watermark=false
needUpdateStringPackage=No
ShopDebug=0
EOF
)"

job_scope() {
  if [ "$1" = "$IOS_JOB_ENTERPRISE" ]; then
    printf 'trigger'
  elif [ "$1" = "$IOS_JOB_CN" ] || [ "$1" = "$IOS_JOB_OS" ]; then
    printf 'query'
  else
    printf 'deny'
  fi
}

job_denied_message() {
  printf '%s' "JOB=${JOB} 不在白名单。可触发的只有 ${IOS_JOB_ENTERPRISE}；可查询的还有 ${IOS_JOB_CN}（cn）与 ${IOS_JOB_OS}（os）"
}

job_trigger_denied_message() {
  printf '%s' "JOB=${JOB} 不能由机器人触发。测试包只触发 ${IOS_JOB_ENTERPRISE}；每日包用 channels"
}

base_mismatch_message() {
  printf '%s' "脚本只连接 ${IOS_BASE}。Android / 鸿蒙用 android.sh / harmony.sh，不要修改 JENKINS_BASE"
}

usage() {
  cat <<'EOF'
用法: ios.sh <子命令> [参数]
凭据: env/ios.env    job 登记: platforms/ios.jobs
JOB 环境变量可用 job 名或别名：enterprise（默认，v6-Enterprise-2）/ cn（国内每日）/ os（海外每日）

  channels [password]                  每日包链接（默认不显示密码；password 才输出密码）
  daily                                每日包主动推送检查入口（挂载层每天定时调用）
  trigger <main_version> confirm [force] [k=v]  触发 v6-Enterprise-2（须 confirm；构建进行中时需 force）
  wait-build queue <排队号>            等到该排队项对应的构建结束
  wait-build <构建号>                  等到这一次构建结束
  wait-build                           仅当该 job 正有一个排队项或正在构建时才等待
  status [构建号]                      查询构建状态
  latest                               该 job 最近成功构建和本次蒲公英链接
  cancel                               列出该 job 的排队项
  cancel <queue_id>                    取消指定排队项
  log [构建号] [行数]                  控制台尾部（默认 30 行）
  jobs                                 列出可见 job
EOF
}

cmd_daily() {
  # 每日包主动推送的检查入口：输出固定渠道与更新说明，供挂载层每天定时调用并推送到群
  cmd_channels ios
  echo
  echo "每日包更新判断：固定链接始终指向最新上传版本。要确认今天是否有新包，需要蒲公英 API Token 查版本列表，或确认每日构建 job 后查 Jenkins lastBuild。"
}

validate_trigger_param() {
  local key="$1" value="$2" normalized
  normalized="$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')"
  case "$normalized" in
    account|password|fabuaccount)
      die "参数 ${key} 禁止由机器人设置"
      ;;
  esac
  case "$key" in
    Service_Key|branch|env|BuildConfiguration|channel|Confusion|Xcode)
      ;;
    needUpload|watermark|needUpdateStringPackage|ShopDebug|main_version)
      ;;
    RNProjectBranch|rnEnv|rnBranchName|dynamicBranchName|team_id_info|PgyerChannel|progressTime)
      ;;
    *) die "trigger 参数 ${key} 不在脚本白名单" ;;
  esac
  case "$value" in
    *$'\n'*|*$'\r'*) die "参数 ${key} 不能包含换行符" ;;
  esac
  if printf '%s' "$value" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    die "参数 ${key} 不能包含控制字符"
  fi
  case "$key" in
    needUpload|needUpdateStringPackage)
      case "$value" in Yes|No) ;; *) die "${key} 只接受 Yes 或 No" ;; esac
      ;;
    watermark)
      case "$value" in true|false) ;; *) die "watermark 只接受 true 或 false" ;; esac
      ;;
  esac
}

cmd_trigger() {
  local confirmed=0 force=0 main_version="" arg key value sk
  for arg in "$@"; do
    if [ "$arg" = "confirm" ]; then
      confirmed=1
      continue
    fi
    if [ "$arg" = "force" ]; then
      force=1
      continue
    fi
    case "$arg" in
      *=*)
        key="${arg%%=*}"
        value="${arg#*=}"
        [ -n "$key" ] || die "无法识别的参数 ${arg}"
        validate_trigger_param "$key" "$value"
        if [ "$key" = "main_version" ]; then
          if [ -n "$main_version" ] && [ "$main_version" != "$value" ]; then
            die "main_version 出现了两个不同的值"
          fi
          main_version="$value"
        else
          upsert_param "$key" "$value"
        fi
        ;;
      *)
        validate_trigger_param main_version "$arg"
        if [ -n "$main_version" ] && [ "$main_version" != "$arg" ]; then
          die "版本号出现了两次：${main_version} 与 ${arg}"
        fi
        main_version="$arg"
        ;;
    esac
  done
  [ "$confirmed" -eq 1 ] || die "trigger 会启动 Jenkins 构建，分发行为以 job 当前配置为准。先向用户复述 job、Service_Key、branch、main_version、env，得到同意后再加上 confirm"
  [ -n "$main_version" ] || die "trigger 需要版本号，例如：trigger 6.10.12 confirm branch=develop"
  sk="$(param_value Service_Key)"
  case "$sk" in
    dev|test) ;;
    *) die "Service_Key=${sk} 需人工在 Jenkins 上触发" ;;
  esac
  upsert_param main_version "$main_version"
  require_job trigger
  load_creds
  # 并发防护：已有进行中/排队构建时拒绝；查询失败也拒绝。force 跳过。
  if [ "$force" -ne 1 ]; then
    ensure_trigger_slot "$main_version"
  fi
  echo "触发构建：JOB=${JOB} main_version=$(param_value main_version)"
  echo "本次打包参数：$(printf '%s' "$PARAMS" | tr '\n' ' ')"
  post_build
  show_trigger_by
  audit_log "trigger JOB=${JOB} Service_Key=$(param_value Service_Key) main_version=$(param_value main_version) branch=$(param_value branch) env=$(param_value env) needUpload=$(param_value needUpload)"
}

CMD="${1:-}"
case "$CMD" in
  channels)
    [ "$#" -le 2 ] || die "channels 参数过多"
    if [ "${2:-}" = "android" ]; then
      die "Android 每日包请执行 android.sh channels"
    fi
    cmd_channels ios "${2:-}"
    ;;
  daily)
    [ "$#" -eq 1 ] || die "daily 不接受参数"
    cmd_daily
    ;;
  trigger) shift; cmd_trigger "$@" ;;
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
