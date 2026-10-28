#!/bin/bash
# HarmonyOS Jenkins. Credentials: $STATE_DIR/env/harmony.env (see common.sh)
# Shared HTTP lives in common.sh. Job rules and parameters stay here.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

HARMONY_BASE="https://jenkins.ninebot.com"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${JENKINS_ENV:-$STATE_DIR/env/harmony.env}"
EXPECTED_BASE="$HARMONY_BASE"
load_env_file "$ENV_FILE"
load_jobs_file "$SKILL_DIR/platforms/harmony.jobs" HARMONY_JOB_AGC HARMONY_JOB_HAP HARMONY_JOB_HAP_DEVELOP HARMONY_JOB_HAP_SIGNER
JENKINS_BASE="${JENKINS_BASE:-$HARMONY_BASE}"

resolve_job() {
  # JOB 可以是登记文件里的 job 名，也可以是别名：agc（默认）
  case "$1" in
    ''|agc|AGC|鸿蒙) printf '%s' "$HARMONY_JOB_AGC" ;;
    *) printf '%s' "$1" ;;
  esac
}
JOB="$(resolve_job "${JOB:-}")"

# Defaults match platforms/harmony.md. Allow-list matches platforms/harmony.jobs.
# build_version / rn_branch_name 留空走 Jenkins 默认（递增计数器 / 不改 RN 分支），
# 因此不放进默认清单，用户显式传入时才发送。
PARAMS="$(cat <<'EOF'
products=default-prod
branch=develop
kuikly_branch_name=develop
app_desc=jenkins
auto_submit=true
distribute_mode=1
EOF
)"

# 完成后回显与 params 展示的参数白名单；凭据类参数永远不在其中。
PARAM_ALLOWLIST="products main_version branch kuikly_branch_name build_version rn_branch_name app_desc auto_submit distribute_mode"

param_manifest_local() {
  cat <<EOF
可触发 job：${HARMONY_JOB_AGC}（别名 agc/鸿蒙，默认）
可查询 job：${HARMONY_JOB_HAP}、${HARMONY_JOB_HAP_DEVELOP}、${HARMONY_JOB_HAP_SIGNER}（只查询、取消排队）。

触发参数（未指定走默认；开发者逐项选择后，复述完整生效参数再 confirm）：
- main_version：必填，版本号（实时清单 params live 给 Jenkins 当前候选）
- products：默认 default-prod（测试环境）；online-prod 生产环境由人在 Jenkins 触发
- branch：默认 develop；常见 develop / release，或直接输入 feature 分支名（实时清单：params live）
- kuikly_branch_name：默认 develop；kuikly 工程分支（当前候选只有 develop）
- build_version：默认不发送，留空由打包机计数器递增；填写须为 1-4 位数字
- rn_branch_name：默认不发送，留空不改 RN 模块分支；需要时填 RN 分支名
- app_desc：默认 jenkins；邀请测试版本说明（自由输入）
- auto_submit：默认 true；可选 true / false（false 只打包不提交 AGC 邀请测试审核）
- distribute_mode：默认 1（仅测试）；2 应用市场由人在 Jenkins 触发

查看 Jenkins 实时候选分支 / 版本 / 选项：harmony.sh params live
EOF
}

job_scope() {
  if [ "$1" = "$HARMONY_JOB_AGC" ]; then
    printf 'trigger'
  elif [ "$1" = "$HARMONY_JOB_HAP" ] || [ "$1" = "$HARMONY_JOB_HAP_DEVELOP" ] || [ "$1" = "$HARMONY_JOB_HAP_SIGNER" ]; then
    printf 'query'
  else
    printf 'deny'
  fi
}

job_denied_message() {
  printf '%s' "JOB=${JOB} 不在白名单。可触发的只有 ${HARMONY_JOB_AGC}；可查询的还有 ${HARMONY_JOB_HAP}、${HARMONY_JOB_HAP_DEVELOP}、${HARMONY_JOB_HAP_SIGNER}"
}

job_trigger_denied_message() {
  printf '%s' "JOB=${JOB} 不能由机器人触发。鸿蒙邀请测试包只触发 ${HARMONY_JOB_AGC}"
}

base_mismatch_message() {
  printf '%s' "脚本只连接 ${HARMONY_BASE}（鸿蒙）。iOS 用 ios.sh，不要修改 JENKINS_BASE"
}

platform_artifact_info() {
  # 鸿蒙产物走 AGC 邀请测试，不上蒲公英：从控制台提取分享链接与 versionCode。
  local num="$1" path console link vc
  path="$(job_path)"
  console="$(mktemp)"
  if ! api_get "/job/${path}/${num}/consoleText" quiet > "$console"; then
    rm -f "$console"
    echo "产物信息暂不可用。构建页：${JENKINS_BASE}/job/${path}/${num}/"
    return 0
  fi
  link="$(grep -oE 'Invited test share link: https://[^ ]+' "$console" | head -n 1 | sed 's/Invited test share link: //' || true)"
  if [ -z "$link" ]; then
    link="$(grep -oE '分享链接: https://[^ ]+' "$console" | head -n 1 | sed 's/分享链接: //' || true)"
  fi
  vc="$(sed -nE 's/.*versionCode [0-9]+ -> ([0-9]+).*/\1/p' "$console" | tail -n 1)"
  if [ -n "$link" ]; then
    echo "邀请测试链接：${link}"
  fi
  if [ -n "$vc" ]; then
    echo "versionCode：${vc}"
  fi
  if [ -z "$link" ] && [ -z "$vc" ]; then
    echo "控制台未提取到邀请测试链接。构建页：${JENKINS_BASE}/job/${path}/${num}/"
  fi
  rm -f "$console"
}

usage() {
  cat <<'EOF'
用法: harmony.sh <子命令> [参数]
凭据: env/harmony.env    job 登记: platforms/harmony.jobs
JOB 环境变量可用 job 名或别名：agc（默认，ninebot-harmony-agc）

  params [live]                        触发前可选参数清单（local 本地默认；live 拉 Jenkins 实时候选）
  trigger <main_version> confirm [force] [k=v]  触发 ninebot-harmony-agc（须 confirm；构建进行中时需 force）
  wait-build queue <排队号>            等到该排队项对应的构建结束
  wait-build <构建号>                  等到这一次构建结束
  wait-build                           仅当该 job 正有一个排队项或正在构建时才等待
  status [构建号]                      查询构建状态
  latest                               该 job 最近成功构建和邀请测试链接
  cancel                               列出该 job 的排队项
  cancel <queue_id>                    取消指定排队项
  log [构建号] [行数]                  控制台尾部（默认 30 行）
  jobs                                 列出可见 job

鸿蒙没有每日包渠道命令（channels / daily 请用 ios.sh / android.sh）。
EOF
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
    products|branch|kuikly_branch_name|app_desc|auto_submit|main_version)
      ;;
    build_version|rn_branch_name|distribute_mode)
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
    products)
      case "$value" in
        default-prod) ;;
        *) die "products=${value} 需人工在 Jenkins 上触发（online-prod 是生产环境）" ;;
      esac
      ;;
    distribute_mode)
      case "$value" in
        1) ;;
        *) die "distribute_mode=${value} 需人工在 Jenkins 上触发（2 是应用市场包）" ;;
      esac
      ;;
    build_version)
      if [ -n "$value" ] && ! printf '%s' "$value" | grep -Eq '^[0-9]{1,4}$'; then
        die "build_version 必须是 1-4 位数字（留空由打包机递增）"
      fi
      ;;
    auto_submit)
      case "$value" in true|false) ;; *) die "auto_submit 只接受 true 或 false" ;; esac
      ;;
  esac
}

cmd_trigger() {
  local confirmed=0 force=0 main_version="" arg key value
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
  [ "$confirmed" -eq 1 ] || die "trigger 会构建鸿蒙包并提交 AGC 邀请测试审核。先向用户复述 job、main_version、branch、products、distribute_mode，得到同意后再加上 confirm"
  [ -n "$main_version" ] || die "trigger 需要版本号，例如：trigger 6.10.13 confirm branch=develop"
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
  audit_log "trigger JOB=${JOB} products=$(param_value products) main_version=$(param_value main_version) branch=$(param_value branch) distribute_mode=$(param_value distribute_mode) auto_submit=$(param_value auto_submit)"
}

CMD="${1:-}"
case "$CMD" in
  channels|daily)
    die "鸿蒙没有每日包渠道。iOS / Android 渠道用 ios.sh / android.sh 的 channels"
    ;;
  params)
    [ "$#" -le 2 ] || die "params 最多接受 local / live"
    shift; cmd_params "$@"
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
