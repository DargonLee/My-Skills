# Shared Jenkins Remote API helpers. Source from a platform script; do not execute.
# Bash 3.2 compatible.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "错误：common.sh 由平台脚本加载，不要直接执行。" >&2
  exit 2
fi

if [ -z "${CHANNELS_FILE:-}" ]; then
  _COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  CHANNELS_FILE="$(cd "$_COMMON_DIR/.." && pwd)/env/channels"
fi
if [ -z "${AUDIT_FILE:-}" ]; then
  _AUDIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  AUDIT_FILE="$_AUDIT_DIR/logs/audit.log"
fi
COOKIE_JAR="$(mktemp)"
API_STATUS_FILE="$(mktemp)"
trap 'rm -f "$COOKIE_JAR" "$API_STATUS_FILE"' EXIT
PARAMS=""

die() {
  echo "错误：$*" >&2
  exit 2
}

load_env_file() {
  local file="$1"
  local keep_user="" keep_token="" keep_base=""
  local has_user=0 has_token=0 has_base=0
  if [ -n "${JENKINS_USER+x}" ] && [ -n "$JENKINS_USER" ]; then
    has_user=1
    keep_user="$JENKINS_USER"
  fi
  if [ -n "${JENKINS_API_TOKEN+x}" ] && [ -n "$JENKINS_API_TOKEN" ]; then
    has_token=1
    keep_token="$JENKINS_API_TOKEN"
  fi
  if [ -n "${JENKINS_BASE+x}" ] && [ -n "$JENKINS_BASE" ]; then
    has_base=1
    keep_base="$JENKINS_BASE"
  fi
  if [ -s "$file" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$file"
    set +a
  fi
  if [ "$has_user" -eq 1 ]; then JENKINS_USER="$keep_user"; fi
  if [ "$has_token" -eq 1 ]; then JENKINS_API_TOKEN="$keep_token"; fi
  if [ "$has_base" -eq 1 ]; then JENKINS_BASE="$keep_base"; fi
}

load_jobs_file() {
  # load_jobs_file <登记文件> <所需键...>：登记必须完整，不能回退到同名环境变量。
  local file="$1" line key value required found
  shift
  [ -s "$file" ] || die "缺少 job 登记文件 ${file}"
  [ "$#" -gt 0 ] || die "平台脚本未声明所需 job 登记键"
  for required in "$@"; do
    unset "$required"
  done
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      ''|'#'*) continue ;;
    esac
    key="${line%%=*}"
    value="${line#*=}"
    printf '%s' "$key" | grep -Eq '^[A-Z]+_JOB_[A-Z_]+$' || die "job 登记文件格式错误：${line}"
    found=0
    for required in "$@"; do
      [ "$key" != "$required" ] || found=1
    done
    [ "$found" -eq 1 ] || die "job 登记文件含未声明的键：${key}"
    [ -n "$value" ] || die "job 登记 ${key} 为空"
    printf -v "$key" '%s' "$value"
  done < "$file"
  for required in "$@"; do
    [ -n "${!required:-}" ] || die "job 登记文件缺少 ${required}"
  done
}

load_creds() {
  if [ -z "${EXPECTED_BASE:-}" ]; then
    die "平台脚本未设置 EXPECTED_BASE"
  fi
  if [ "${JENKINS_BASE:-}" != "$EXPECTED_BASE" ]; then
    if type base_mismatch_message >/dev/null 2>&1; then
      die "$(base_mismatch_message)"
    fi
    die "该脚本只连接 ${EXPECTED_BASE}"
  fi
  if [ -z "${JENKINS_USER:-}" ] || [ -z "${JENKINS_API_TOKEN:-}" ]; then
    die "缺少凭据。写入 ${ENV_FILE}（chmod 600），或导出 JENKINS_USER / JENKINS_API_TOKEN"
  fi
  AUTH="${JENKINS_USER}:${JENKINS_API_TOKEN}"
}

require_job() {
  local need="$1" scope
  scope="$(job_scope "$JOB")"
  if [ "$scope" = "deny" ]; then
    if type job_denied_message >/dev/null 2>&1; then
      die "$(job_denied_message)"
    fi
    die "JOB=${JOB} 不在白名单"
  fi
  if [ "$need" = "trigger" ] && [ "$scope" != "trigger" ]; then
    if type job_trigger_denied_message >/dev/null 2>&1; then
      die "$(job_trigger_denied_message)"
    fi
    die "JOB=${JOB} 不能由该脚本触发"
  fi
}

upsert_param() {
  local key="$1" value="$2" line name out="" found=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    name="${line%%=*}"
    if [ "$name" = "$key" ]; then
      out="${out}${key}=${value}"$'\n'
      found=1
    else
      out="${out}${line}"$'\n'
    fi
  done <<EOF
$PARAMS
EOF
  if [ "$found" -eq 0 ]; then
    out="${out}${key}=${value}"$'\n'
  fi
  PARAMS="$out"
}

param_value() {
  local key="$1" line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ "${line%%=*}" = "$key" ]; then
      printf '%s' "${line#*=}"
      return 0
    fi
  done <<EOF
$PARAMS
EOF
}

job_path() {
  python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$JOB"
}

get_crumb() {
  local hf code crumb
  hf="$(mktemp)"
  code="$(curl -sS -g -m 20 -c "$COOKIE_JAR" -u "$AUTH" -o "$hf" -w '%{http_code}' \
    "$JENKINS_BASE/crumbIssuer/api/json")" || {
    rm -f "$hf"
    echo "错误：无法连接 Jenkins" >&2
    exit 1
  }
  if [ "$code" != "200" ]; then
    rm -f "$hf"
    echo "错误：获取 crumb 失败 HTTP ${code}" >&2
    exit 1
  fi
  crumb="$(python3 -c 'import json,sys
try:
    print(json.load(sys.stdin)["crumb"])
except Exception:
    sys.stderr.write("错误：crumb 响应无法解析\n")
    sys.exit(1)' < "$hf")" || {
    rm -f "$hf"
    exit 1
  }
  rm -f "$hf"
  printf '%s' "$crumb"
}

_api_note() {
  # api_get 常在 $(...) 里运行，shell 变量带不回父进程，所以把 HTTP 状态写进文件。
  printf '%s' "${API_HTTP_CODE:-}" > "$API_STATUS_FILE"
}

_load_api_status() {
  API_HTTP_CODE="$(cat "$API_STATUS_FILE" 2>/dev/null || true)"
}

api_get() {
  # 第二个参数为 quiet 时，失败不打印（调用方自己报错）。
  local hf code quiet="${2:-}"
  hf="$(mktemp)"
  API_HTTP_CODE=""
  code="$(curl -sS -g -m 30 -u "$AUTH" -o "$hf" -w '%{http_code}' "$JENKINS_BASE$1")" || {
    rm -f "$hf"
    API_HTTP_CODE="000"
    _api_note
    if [ "$quiet" != "quiet" ]; then
      echo "错误：无法连接 Jenkins" >&2
    fi
    return 1
  }
  API_HTTP_CODE="$code"
  _api_note
  if ! printf '%s' "$code" | grep -Eq '^2'; then
    rm -f "$hf"
    if [ "$quiet" != "quiet" ]; then
      echo "错误：请求失败 HTTP ${code} ($1)" >&2
    fi
    return 1
  fi
  cat "$hf"
  rm -f "$hf"
}

post_build() {
  local args=() line crumb hf code loc path qid num tries
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    args+=(--data-urlencode "$line")
  done <<EOF
$PARAMS
EOF
  crumb="$(get_crumb)"
  path="$(job_path)"
  hf="$(mktemp)"
  code="$(curl -sS -g -m 30 -b "$COOKIE_JAR" -u "$AUTH" -H "Jenkins-Crumb: ${crumb}" -X POST \
    "$JENKINS_BASE/job/${path}/buildWithParameters" "${args[@]}" -o /dev/null -D "$hf" -w '%{http_code}')" || {
    rm -f "$hf"
    echo "错误：触发请求未得到响应，结果不确定。先检查队列和构建状态，不要直接重试" >&2
    exit 1
  }
  loc="$(grep -i '^location:' "$hf" | head -n 1 | sed 's/^[Ll]ocation: //' | tr -d '\r' || true)"
  rm -f "$hf"
  echo "HTTP ${code}"
  case "$code" in
    200|201|303)
      if [ -n "$loc" ]; then
        qid="$(printf '%s' "$loc" | sed -nE 's#.*/queue/item/([0-9]+)/.*#\1#p' | head -n 1)"
        if [ -n "$qid" ]; then
          echo "已入队：${loc}"
          echo "排队号：${qid}"
          # 排队 id 已绑定，再尽力取本次构建号。
          num=""
          tries=0
          while [ "$tries" -lt 10 ] && [ -z "$num" ]; do
            num="$(api_get "/queue/item/${qid}/api/json?tree=executable[number]" 2>/dev/null | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print((d.get("executable") or {}).get("number") or "")' || true)"
            [ -n "$num" ] || { tries=$((tries + 1)); sleep 2; }
          done
          if [ -n "$num" ]; then
            echo "本次构建：#${num}"
          else
            echo "构建排队中：构建号待构建开始后由 status / wait-build 显示"
          fi
        else
          echo "Jenkins 返回的地址不是排队项：${loc}；无法绑定本次构建。先检查队列和构建状态，不要直接重试"
        fi
      else
        echo "Jenkins 未返回排队地址；无法绑定本次构建。先检查队列和构建状态，不要直接重试"
      fi
      ;;
    *)
      echo "触发请求返回 HTTP ${code}，结果可能不确定。先检查队列和构建状态，不要直接重试" >&2
      exit 1
      ;;
  esac
}

cmd_channels() {
  local which="${1:-}" with_pwd="${2:-}"
  case "$which" in
    ios|android) ;;
    *) die "channels 只接受 ios 或 android" ;;
  esac
  if [ -n "$with_pwd" ] && [ "$with_pwd" != "password" ]; then
    die "channels 只接受 password 子参数"
  fi
  [ -s "$CHANNELS_FILE" ] || die "缺少 ${CHANNELS_FILE}。按 README 创建并写入链接和密码"
  python3 - "$CHANNELS_FILE" "$which" "$with_pwd" <<'PY'
import sys
path, which, with_pwd = sys.argv[1], sys.argv[2], sys.argv[3]
show_pwd = with_pwd == "password"
groups = {
    "ios": ["IOS_CN_URL", "IOS_CN_PASSWORD", "IOS_OS_URL", "IOS_OS_PASSWORD"],
    "android": ["ANDROID_CN_URL", "ANDROID_CN_PASSWORD", "ANDROID_OS_URL", "ANDROID_OS_PASSWORD"],
}
labels = {
    "IOS_CN_URL": "iOS 国内每日包",
    "IOS_CN_PASSWORD": "iOS 国内密码",
    "IOS_OS_URL": "iOS 海外每日包",
    "IOS_OS_PASSWORD": "iOS 海外密码",
    "ANDROID_CN_URL": "Android 国内每日包",
    "ANDROID_CN_PASSWORD": "Android 国内密码",
    "ANDROID_OS_URL": "Android 海外每日包",
    "ANDROID_OS_PASSWORD": "Android 海外密码",
}
vals = {}
for raw in open(path, encoding="utf-8"):
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    key, value = key.strip(), value.strip().strip('"').strip("'")
    if key in labels:
        vals[key] = value
missing = [key for key in groups[which] if not vals.get(key)]
for key in groups[which]:
    if vals.get(key):
        if key.endswith("_PASSWORD") and not show_pwd:
            continue
        print("%s: %s" % (labels[key], vals[key]))
if not show_pwd:
    print("密码不直接展示。确认需要时执行 %s.sh channels password" % which)
if missing:
    sys.stderr.write("缺少 " + ", ".join(missing) + "\n")
    sys.exit(2)
PY
}

cmd_status() {
  local num="${1:-}" path body bnum result building
  if [ -n "$num" ] && ! printf '%s' "$num" | grep -Eq '^[0-9]+$'; then
    die "构建号必须是数字"
  fi
  require_job query
  load_creds
  path="$(job_path)"
  if [ -n "$num" ]; then
    path="/job/${path}/${num}/api/json?tree=number,result,building,duration,timestamp,url"
  else
    path="/job/${path}/lastBuild/api/json?tree=number,result,building,duration,timestamp,url"
  fi
  body="$(api_get "$path" quiet)" || {
    _load_api_status
    if [ "${API_HTTP_CODE:-}" = "404" ]; then
      if [ -n "$num" ]; then
        die "构建 #${num} 不存在"
      fi
      die "该 job 暂无构建记录"
    fi
    die "无法查询构建状态（HTTP ${API_HTTP_CODE:-000}）"
  }
  bnum="$(printf '%s' "$body" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.stderr.write("错误：Jenkins 返回的不是 JSON\n")
    sys.exit(1)
print(d.get("number") or "")')"
  [ -n "$bnum" ] || die "暂无构建记录"
  result="$(printf '%s' "$body" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
print(d.get("result") or "")')"
  building="$(printf '%s' "$body" | python3 -c 'import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
print("1" if d.get("building") else "")')"
  printf '%s' "$body" | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    data = json.loads(raw)
except Exception:
    sys.stderr.write("错误：Jenkins 返回的不是 JSON\n")
    sys.exit(1)
print("构建 #%s" % data["number"])
if data.get("building"):
    print("状态: 构建中…")
else:
    print("状态: %s" % (data.get("result") or "UNKNOWN"))
duration = data.get("duration") or 0
if duration:
    print("耗时: %.1f 分钟" % (duration / 60000.0))
print("链接: %s" % data.get("url"))
'
  if [ -n "$building" ]; then
    queue_eta 2>/dev/null || true
  elif [ -n "$result" ] && [ "$result" != "SUCCESS" ]; then
    error_summary "$bnum"
  fi
}

show_trigger_by() {
  if [ -n "${JENKINS_TRIGGER_BY:-}" ]; then
    printf '触发人：%s\n' "$(printf '%s' "$JENKINS_TRIGGER_BY" | LC_ALL=C tr -d '[:cntrl:]')"
  fi
}

audit_log() {
  # audit_log <事件> <详情...>：追加一行审计记录到 logs/audit.log（目录 700、文件 600，留在本机不随 skill 分发）
  local dir line
  dir="$(dirname "$AUDIT_FILE")"
  line="$(date '+%Y-%m-%d %H:%M:%S') trigger_by=${JENKINS_TRIGGER_BY:-（无）} $*"
  line="$(printf '%s' "$line" | LC_ALL=C tr -d '[:cntrl:]')"
  if ! mkdir -p "$dir" 2>/dev/null ||
     ! chmod 700 "$dir" 2>/dev/null ||
     ! (umask 077; : >> "$AUDIT_FILE") 2>/dev/null ||
     ! chmod 600 "$AUDIT_FILE" 2>/dev/null ||
     ! (printf '%s\n' "$line" >> "$AUDIT_FILE") 2>/dev/null; then
    echo "警告：构建已触发，但审计日志写入失败；请勿直接重试触发" >&2
  fi
}

error_summary() {
  # error_summary <build_num>：构建非成功时的失败分析。解析控制台输出：
  # 失败步骤、关键报错节点（脱敏）、本次构建的 commit/分支（有 author 则列出提交人）。
  local num="$1" path console csfile
  path="$(job_path)"
  console="$(mktemp)"
  csfile="$(mktemp)"
  if ! api_get "/job/${path}/${num}/consoleText" quiet > "$console"; then
    rm -f "$console" "$csfile"
    echo "失败分析：控制台暂不可用。构建页：${JENKINS_BASE}/job/${path}/${num}/"
    return 0
  fi
  api_get "/job/${path}/${num}/api/json?tree=changeSet[items[author[fullName],msg,timestamp,commitId]]" > "$csfile" 2>/dev/null || true
  python3 - "$console" "$csfile" <<'PY'
import sys, json, re

console_path, cs_path = sys.argv[1], sys.argv[2]
raw = open(console_path, encoding="utf-8", errors="replace").read()
lines = raw.splitlines()

def redact(text):
    text = text.replace("\r", " ").replace("\n", " ")
    if re.search(r"(?i)password|token|authorization|jenkins-crumb|secret=", text):
        return "[已脱敏]"
    return text

print("失败分析：")
# 1. 失败步骤：marked build as failure / BUILD FAILED 所在行
step_lines = [(i + 1, ln) for i, ln in enumerate(lines)
              if "marked build as failure" in ln or "BUILD FAILED" in ln]
if step_lines:
    n, ln = step_lines[-1]
    print("失败步骤（日志行 %d）：%s" % (n, redact(ln)))
else:
    print("失败步骤：未识别到明确的失败步骤标记")

# 2. 关键报错节点：失败步骤之前的独立错误/失败行（排除 warning、deprecated、代码片段、调试打印）
noise = re.compile(
    r"(?i)warning|deprecated| error\?|localizedDescription|onError|error\(\??\)"
    r"|^\s*\d+\s+\||^\s*\*|^\s*[▸⚠️✖]|debugPrint\(error\)|print(Log)?\(.*(error|failed)|ld: .*compiled with"
    r"|failedPaths|failed code|error:&|error:\(|error:nil| due error| error:\s*NSError| error:\s*\(\*"
)
STRONG = re.compile(r"(?i)failed with|upload failed|BUILD FAILED|fatal error|exception[^a-zA-Z]|cannot find|no such file|command not found|undefined symbols?|linker command failed|error:")
key_err = []
for i, ln in enumerate(lines):
    if re.search(r"(?i)(^|[^a-z])error|fatal|exception|failed|✖", ln) and not noise.search(ln):
        key_err.append((i + 1, ln.strip()))
boundary = step_lines[-1][0] if step_lines else len(lines)
before = [e for e in key_err if e[0] < boundary]
strong = [e for e in before if STRONG.search(e[1])]
pool = strong if strong else before
shown = (pool if pool else key_err)[-5:]
if shown:
    print("关键报错节点（最多 5 条，脱敏）：")
    for n, ln in shown:
        print("  - [日志行 %d] %s" % (n, redact(ln)[:300]))
else:
    print("关键报错节点：未提取到独立报错行（可能是资源/上传类错误，见失败步骤）")

# 3. 提交定位：changeSet author 优先；否则从检出日志取 commit + 分支 + message
authors = []
try:
    cs = json.load(open(cs_path, encoding="utf-8"))
    items = (cs.get("changeSet") or {}).get("items") or []
    authors = [(redact(it.get("author", {}).get("fullName") or "?"),
                redact(it.get("msg") or "")[:80])
               for it in items if it.get("commitId") or it.get("msg")]
except Exception:
    items = []

if authors:
    print("本次构建提交：")
    seen = set()
    for who, msg in authors:
        if (who, msg) in seen:
            continue
        seen.add((who, msg))
        print("  - %s: %s" % (who, msg))
    print("提交人：上述提交作者（Jenkins changeSet 提供）")
else:
    pairs = []
    cur = None
    for ln in lines:
        m = re.search(r"Checking out Revision ([0-9a-f]{7,40}) \((.*?)\)", ln)
        if m:
            cur = [m.group(1), redact(m.group(2)), ""]
            pairs.append(cur)
            continue
        m = re.match(r'\s*Commit message:\s*"?(.*?)"?\s*$', ln)
        if m and cur is not None:
            cur[2] = redact(m.group(1))[:80]
    if pairs:
        print("本次构建代码（从控制台检出日志）：")
        for h, branch, msg in pairs:
            print("  - %s @ %s: %s" % (branch, h[:8], msg or "（无 commit message）"))
        print("提交人：控制台未提供 author 信息（changeSet 为空），无法定位到具体提交人。可结合 commit 在 GitLab 上查对应提交记录")
    else:
        print("本次构建代码：控制台未提取到检出信息")
PY
  rm -f "$console" "$csfile"
}

queue_eta() {
  # 输出该 job 当前排队项的原因 / 预计时间（queue 的 why，含 ETA）
  local q
  q="$(api_get "/queue/api/json?tree=items[id,why,task[name]]")"
  printf '%s' "$q" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
job = sys.argv[1]
for item in data.get("items", []):
    if item.get("task", {}).get("name") == job:
        print("排队中（id=%s）：%s" % (item.get("id"), item.get("why") or ""))
        sys.exit(0)
' "$JOB"
}

jenkins_artifact_info() {
  # jenkins_artifact_info <build_num>：只列出 IPA，避免把先归档的日志当成下载包。
  local num="$1" path body
  path="$(job_path)"
  body="$(api_get "/job/${path}/${num}/api/json?tree=url,artifacts[fileName,relativePath]" quiet)" || return 2
  printf '%s' "$body" | python3 -c '
import json, re, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(2)
arts = [a for a in (d.get("artifacts") or [])
        if (a.get("fileName") or "").lower().endswith(".ipa")]
if not arts:
    sys.exit(1)
url = d.get("url") or ""
for a in arts:
    name = a.get("fileName") or ""
    print("产物：%s" % name)
    print("Jenkins 产物下载（需登录）：%sartifact/%s" % (url, a.get("relativePath") or ""))
    m = re.search(r"_v(\d+(?:\.\d+)+)\((\d+)\)", name)
    if m:
        print("版本号：%s.%s" % (m.group(1), m.group(2)))
'
}

pgyer_info() {
  # pgyer_info <build_num>：从该构建控制台提取并输出蒲公英链接与版本号（末段即 app 构建编号）；
  # 控制台没有蒲公英记录时回退到 Jenkins 归档产物，再没有才只给构建页。
  local num="$1" path console pgyer short version arts rc=0 console_ok=1
  path="$(job_path)"
  console="$(mktemp)"
  api_get "/job/${path}/${num}/consoleText" quiet > "$console" || console_ok=0
  pgyer="$(grep -oE '应用构建主页：https://www\.pgyer\.com/[^ ]+' "$console" | head -n 1 | sed 's/应用构建主页：//' || true)"
  short="$(grep -oE '应用短链接：[^ ]+' "$console" | head -n 1 | sed 's/应用短链接：//' || true)"
  version="$(grep -oE '\[UPLOAD TO PGYER\] - 版本号：[^ ]+' "$console" | head -n 1 | sed 's/.*版本号：//' || true)"
  rm -f "$console"
  if [ -n "$pgyer" ]; then
    echo "蒲公英下载：${pgyer}"
    if [ -n "$short" ]; then
      echo "短链接：https://www.pgyer.com/${short}"
    fi
    if [ -n "$version" ]; then
      echo "版本号：${version}"
    fi
    return 0
  fi
  arts="$(jenkins_artifact_info "$num")" || rc=$?
  if [ "$rc" -eq 0 ] && [ -n "$arts" ]; then
    if [ "$console_ok" -eq 1 ]; then
      echo "蒲公英：控制台无上传记录，改给 Jenkins 归档产物"
    else
      echo "蒲公英：控制台暂不可用，改给 Jenkins 归档产物"
    fi
    printf '%s\n' "$arts"
  elif [ "$console_ok" -ne 1 ] || [ "$rc" -eq 2 ]; then
    echo "产物信息暂不可用。构建页：${JENKINS_BASE}/job/${path}/${num}/"
  else
    echo "控制台未提取到蒲公英链接。构建页：${JENKINS_BASE}/job/${path}/${num}/"
  fi
}

artifact_info() {
  # artifact_info <build_num>：成功构建的产物信息。默认提取蒲公英；
  # 平台脚本定义 platform_artifact_info 时改用它（如鸿蒙的 AGC 邀请测试链接）。
  if type platform_artifact_info >/dev/null 2>&1; then
    platform_artifact_info "$1"
  else
    pgyer_info "$1"
  fi
}

build_in_progress() {
  # 0=该 job 有排队项或正在构建，1=没有，2=查询失败（不得当成「没有」）。
  # 调用前需已 load_creds（依赖 AUTH）且 JOB 已设置。
  local path q lb rc
  path="$(job_path)"
  q="$(api_get "/queue/api/json?tree=items[id,task[name]]")" || return 2
  rc=0
  printf '%s' "$q" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(2)
job = sys.argv[1]
if any(item.get("task", {}).get("name") == job for item in data.get("items", [])):
    sys.exit(0)
sys.exit(1)
' "$JOB" || rc=$?
  if [ "$rc" -eq 0 ]; then
    return 0
  fi
  if [ "$rc" -ne 1 ]; then
    return 2
  fi
  lb="$(api_get "/job/${path}/lastBuild/api/json?tree=number,building")" || {
    _load_api_status
    if [ "${API_HTTP_CODE:-}" = "404" ]; then
      return 1
    fi
    return 2
  }
  rc=0
  printf '%s' "$lb" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(2)
sys.exit(0 if d.get("building") else 1)
' || rc=$?
  if [ "$rc" -eq 0 ]; then
    return 0
  fi
  if [ "$rc" -eq 1 ]; then
    return 1
  fi
  return 2
}

ensure_trigger_slot() {
  # 查询失败时拒绝触发。force 由调用方跳过本函数。
  local version="${1:-}" rc=0 hint="trigger"
  if [ -n "$version" ]; then
    hint="trigger ${version} confirm force"
  fi
  build_in_progress || rc=$?
  if [ "$rc" -eq 0 ]; then
    die "该 job 已有构建进行中或排队中。确认需要重复触发，请加 force：${hint}"
  fi
  if [ "$rc" -ne 1 ]; then
    die "无法确认该 job 是否已有构建进行中或排队中，已拒绝触发。请稍后重试，或确认后加 force：${hint}"
  fi
}

_wait_tick() {
  local again="${1:-wait-build}"
  _WAIT_TRIES=$((_WAIT_TRIES + 1))
  if [ "$_WAIT_TRIES" -ge "$max_tries" ]; then
    die "等待超时（轮询上限 ${max_tries} 次），构建可能仍在进行；可再次执行 ${again}"
  fi
  sleep 15
}

build_number_for_queue() {
  # 在最近构建里按 queueId 找构建号。0 且 stdout 为号码；1=没有；2=查不到。
  local qid="$1" body
  body="$(api_get "/job/$(job_path)/api/json?tree=builds[number,queueId]{0,20}")" || return 2
  printf '%s' "$body" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(2)
want = int(sys.argv[1])
for build in data.get("builds") or []:
    try:
        qid = int(build.get("queueId"))
    except (TypeError, ValueError):
        continue
    if qid == want and build.get("number"):
        print(build["number"])
        sys.exit(0)
sys.exit(1)
' "$qid"
}

resolve_queue_id() {
  # 把排队号解析成 _WAIT_BUILD_NUM。排队项消失时只接受 queueId 相符的构建。
  local qid="$1" body rc num misses=0
  echo "等待排队项 ${qid}"
  _WAIT_BUILD_NUM=""
  while true; do
    rc=0
    body="$(api_get "/queue/item/${qid}/api/json?tree=executable[number],cancelled" quiet)" || rc=$?
    _load_api_status
    if [ "$rc" -ne 0 ]; then
      if [ "${API_HTTP_CODE:-}" != "404" ]; then
        die "无法查询排队项 ${qid}，已停止等待"
      fi
      rc=0
      num="$(build_number_for_queue "$qid")" || rc=$?
      if [ "$rc" -eq 0 ] && [ -n "$num" ]; then
        _WAIT_BUILD_NUM="$num"
        return 0
      fi
      if [ "$rc" -ne 1 ]; then
        die "无法按排队号 ${qid} 查找构建，已停止等待"
      fi
      misses=$((misses + 1))
      if [ "$misses" -ge 4 ]; then
        die "排队项 ${qid} 已不在队列中，最近 20 次构建没有这个排队号。请用 status 核对，不要把上一次构建当作本次结果"
      fi
      _wait_tick "wait-build queue ${qid}"
      continue
    fi
    misses=0
    rc=0
    num="$(printf '%s' "$body" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(2)
if d.get("cancelled"):
    sys.exit(3)
num = (d.get("executable") or {}).get("number")
if num:
    print(num)
    sys.exit(0)
sys.exit(1)
')" || rc=$?
    if [ "$rc" -eq 0 ] && [ -n "$num" ]; then
      _WAIT_BUILD_NUM="$num"
      return 0
    fi
    if [ "$rc" -eq 3 ]; then
      die "排队项 ${qid} 已取消"
    fi
    if [ "$rc" -ne 1 ]; then
      die "排队项 ${qid} 的状态无法解析，已停止等待"
    fi
    _wait_tick "wait-build queue ${qid}"
  done
}

wait_until_settled() {
  local num="$1" body building rc
  echo "等待构建 #${num}"
  while true; do
    body="$(api_get "/job/$(job_path)/${num}/api/json?tree=number,building,result")" || die "无法查询构建 #${num}，已停止等待"
    rc=0
    building="$(printf '%s' "$body" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(2)
print("1" if d.get("building") or not d.get("result") else "0")
')" || rc=$?
    if [ "$rc" -ne 0 ] || [ -z "$building" ]; then
      die "构建 #${num} 的状态无法解析，已停止等待"
    fi
    if [ "$building" = "0" ]; then
      return 0
    fi
    _wait_tick "wait-build ${num}"
  done
}

notify_local() {
  # notify_local <标题> <正文> [链接] [声音]：JENKINS_NOTIFY=1 时发一条本机 macOS 通知。
  # 只通知坐在这台 Mac 前的使用者；发送失败静默跳过，不影响结果输出。授权方法见 README「本机 macOS 通知」。
  [ "${JENKINS_NOTIFY:-}" = "1" ] || return 0
  local title="$1" body="$2" url="${3:-}" sound="${4:-Glass}"
  if command -v terminal-notifier >/dev/null 2>&1; then
    if [ -n "$url" ]; then
      terminal-notifier -title "$title" -message "$body" -sound "$sound" -group jenkins-build \
        -open "$url" >/dev/null 2>&1 || true
    else
      terminal-notifier -title "$title" -message "$body" -sound "$sound" -group jenkins-build \
        >/dev/null 2>&1 || true
    fi
  else
    title="${title//\"/\\\"}"
    body="${body//\"/\\\"}"
    osascript -e "display notification \"${body}\" with title \"${title}\" sound name \"${sound}\"" \
      >/dev/null 2>&1 || true
  fi
}

report_build() {
  local num="$1" body result dur_min arts vline link
  body="$(api_get "/job/$(job_path)/${num}/api/json?tree=number,result,building,duration,timestamp,url")" || die "无法读取构建 #${num} 的结果"
  result="$(printf '%s' "$body" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
print(d.get("result") or "")
')" || die "构建 #${num} 的结果无法解析"
  dur_min="$(printf '%s' "$body" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
ms = d.get("duration") or 0
print("%.1f" % (ms / 60000.0) if ms else "")
' || true)"
  printf '%s' "$body" | python3 -c '
import json, sys
try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.stderr.write("错误：Jenkins 返回的不是 JSON\n")
    sys.exit(1)
print("构建 #%s" % data["number"])
if data.get("building"):
    print("状态: 构建中…")
else:
    print("状态: %s" % (data.get("result") or "UNKNOWN"))
duration = data.get("duration") or 0
if duration:
    print("耗时: %.1f 分钟" % (duration / 60000.0))
print("链接: %s" % data.get("url"))
' || die "构建 #${num} 的结果无法解析"
  show_trigger_by
  if [ "$result" = "SUCCESS" ]; then
    arts="$(artifact_info "$num")"
    printf '%s\n' "$arts"
    vline="$(printf '%s\n' "$arts" | grep '^版本号：' | head -n 1 | sed 's/^版本号：//' || true)"
    link="$(printf '%s\n' "$arts" | grep -oE 'https://[^ ]+' | head -n 1 || true)"
    notify_local "Jenkins 打包助手" \
      "构建 #${num} · SUCCESS${dur_min:+ · 耗时 ${dur_min} 分钟}${vline:+ · ${vline}}" \
      "$link" "Glass"
  else
    error_summary "$num"
    notify_local "Jenkins 打包助手" \
      "构建 #${num} · ${result} ·${dur_min:+ 耗时 ${dur_min} 分钟}详见 wait-build 输出" \
      "" "Basso"
  fi
}

pick_single_queue_id() {
  # 0 且 stdout 为唯一排队号；1=没有；2=查询失败；3=多于一个。
  local body rc id
  body="$(api_get "/queue/api/json?tree=items[id,task[name]]")" || return 2
  rc=0
  id="$(printf '%s' "$body" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(2)
job = sys.argv[1]
ids = [item.get("id") for item in data.get("items", []) if item.get("task", {}).get("name") == job]
if len(ids) > 1:
    sys.exit(3)
if len(ids) == 1 and ids[0] is not None:
    print(ids[0])
    sys.exit(0)
sys.exit(1)
' "$JOB")" || rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '%s' "$id"
    return 0
  fi
  return "$rc"
}

pick_building_number() {
  # 0 且 stdout 为正在构建的 lastBuild 号；1=没有在构建（含 404）；2=查询失败。
  local body rc num
  body="$(api_get "/job/$(job_path)/lastBuild/api/json?tree=number,building")" || {
    _load_api_status
    if [ "${API_HTTP_CODE:-}" = "404" ]; then
      return 1
    fi
    return 2
  }
  rc=0
  num="$(printf '%s' "$body" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(2)
if d.get("building") and d.get("number"):
    print(d["number"])
    sys.exit(0)
sys.exit(1)
')" || rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '%s' "$num"
    return 0
  fi
  return "$rc"
}

cmd_wait_build() {
  # wait-build [queue <排队号> | <构建号>]
  # 只报告这一次排队项或构建号。未指定时，仅当该 job 恰好只有一个排队项，或只有一个
  # 运行中的构建（两者不同时存在）才等待；空闲、歧义或查询失败都拒绝，不回退 lastBuild。
  local arg1="${1:-}" arg2="${2:-}" queue_id="" target="" rc=0 active_rc=0 max_tries
  max_tries="${WAIT_BUILD_MAX_TRIES:-120}"
  case "$max_tries" in ''|*[!0-9]*|0) max_tries=120 ;; esac
  if [ "$arg1" = "queue" ]; then
    [ -n "$arg2" ] || die "wait-build queue 需要排队号"
    printf '%s' "$arg2" | grep -Eq '^[0-9]+$' || die "排队号必须是数字"
    [ -z "${3:-}" ] || die "wait-build 参数过多"
    queue_id="$arg2"
  elif [ -n "$arg1" ]; then
    printf '%s' "$arg1" | grep -Eq '^[0-9]+$' || die "构建号必须是数字"
    [ -z "${2:-}" ] || die "wait-build 参数过多"
    target="$arg1"
  fi
  require_job query
  load_creds
  _WAIT_TRIES=0
  _WAIT_BUILD_NUM=""
  queue_eta || true
  if [ -z "$target" ] && [ -z "$queue_id" ]; then
    rc=0
    queue_id="$(pick_single_queue_id)" || rc=$?
    if [ "$rc" -eq 3 ]; then
      die "该 job 有多个排队项。请指定本次排队号：wait-build queue <id>"
    fi
    if [ "$rc" -eq 2 ]; then
      die "无法确认该 job 是否在排队，已停止等待。请传入本次排队号或构建号"
    fi
    if [ "$rc" -eq 0 ]; then
      target="$(pick_building_number)" || active_rc=$?
      if [ "$active_rc" -eq 2 ]; then
        die "无法确认该 job 是否同时有运行中的构建，已停止等待。请传入本次排队号或构建号"
      fi
      if [ "$active_rc" -eq 0 ]; then
        die "该 job 同时有排队项和运行中的构建。请指定本次排队号或构建号"
      fi
      target=""
    else
      queue_id=""
      rc=0
      target="$(pick_building_number)" || rc=$?
      if [ "$rc" -eq 2 ]; then
        die "无法确认该 job 是否在构建，已停止等待。请传入本次排队号或构建号"
      fi
      if [ "$rc" -ne 0 ] || [ -z "$target" ]; then
        die "当前没有进行中的排队或构建。等待本次触发请传入排队号或构建号：wait-build queue <排队号>，或 wait-build <构建号>"
      fi
    fi
  fi
  if [ -n "$queue_id" ]; then
    resolve_queue_id "$queue_id"
    target="${_WAIT_BUILD_NUM}"
    [ -n "$target" ] || die "排队项 ${queue_id} 没有产生构建号"
  fi
  wait_until_settled "$target"
  report_build "$target"
}

cmd_latest() {
  local path num dur body
  require_job query
  load_creds
  path="$(job_path)"
  body="$(api_get "/job/${path}/lastSuccessfulBuild/api/json?tree=number,result,duration,timestamp,url" quiet)" || {
    _load_api_status
    if [ "${API_HTTP_CODE:-}" = "404" ]; then
      die "该 job 暂无成功构建"
    fi
    die "无法查询最近成功构建（HTTP ${API_HTTP_CODE:-000}）"
  }
  num="$(printf '%s' "$body" | python3 -c 'import json,sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.stderr.write("错误：Jenkins 返回的不是 JSON\n")
    sys.exit(1)
print(data.get("number") or "")')"
  [ -n "$num" ] || die "该 job 暂无成功构建"
  dur="$(printf '%s' "$body" | python3 -c 'import json,sys
data = json.load(sys.stdin)
duration = data.get("duration") or 0
print(round(duration / 60000.0, 1) if duration else "")')"
  echo "最近成功构建：#${num}"
  if [ -n "$dur" ] && [ "$dur" != "0" ] && [ "$dur" != "0.0" ]; then
    echo "耗时: ${dur} 分钟"
  fi
  artifact_info "$num"
}

cmd_cancel() {
  local id="${1:-}" items path
  if [ -n "$id" ] && ! printf '%s' "$id" | grep -Eq '^[0-9]+$'; then
    die "cancel 需要队列数字 id。先不带参数执行 cancel"
  fi
  require_job query
  load_creds
  items="$(api_get "/queue/api/json?tree=items[id,why,task[name]]")"
  if [ -z "$id" ]; then
    printf '%s' "$items" | python3 -c 'import json,sys
raw = sys.stdin.read()
try:
    data = json.loads(raw)
except Exception:
    sys.stderr.write("错误：队列响应不是 JSON\n")
    sys.exit(1)
job = sys.argv[1]
rows = [item for item in data.get("items", []) if item.get("task", {}).get("name") == job]
if not rows:
    print("队列中没有 %s 的排队任务。运行中的构建不会停止。" % job)
else:
    print("排队中：")
    for item in rows:
        print("- id=%s %s" % (item.get("id"), item.get("why") or ""))
    print("未取消。用户确认 id 后执行 cancel <id>")
' "$JOB"
    return 0
  fi
  printf '%s' "$items" | python3 -c 'import json,sys
try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.stderr.write("错误：队列响应不是 JSON\n")
    sys.exit(1)
job, wanted = sys.argv[1], int(sys.argv[2])
ok = any(item.get("id") == wanted and item.get("task", {}).get("name") == job for item in data.get("items", []))
if not ok:
    sys.stderr.write("错误：队列 id %s 不是 %s 的排队项\n" % (wanted, job))
    sys.exit(2)
' "$JOB" "$id"
  path="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$id")"
  local crumb hf code
  crumb="$(get_crumb)"
  code="$(curl -sS -g -m 30 -b "$COOKIE_JAR" -u "$AUTH" -H "Jenkins-Crumb: ${crumb}" -X POST \
    "$JENKINS_BASE/queue/cancelItem?id=${path}" -o /dev/null -w '%{http_code}')" || {
    echo "错误：无法连接 Jenkins" >&2
    exit 1
  }
  case "$code" in
    200|201|204|302) echo "已取消排队任务（queue item ${id}）" ;;
    *)
      echo "取消失败（HTTP ${code}）" >&2
      exit 1
      ;;
  esac
}

redact_log() {
  grep -viE 'password|token|authorization|jenkins-crumb|secret=' || true
}

cmd_log() {
  local num="${1:-}" lines="${2:-30}" path
  if [ -n "$num" ] && ! printf '%s' "$num" | grep -Eq '^[0-9]+$'; then
    die "构建号必须是数字"
  fi
  printf '%s' "$lines" | grep -Eq '^[0-9]+$' || die "行数必须是数字"
  require_job query
  load_creds
  path="$(job_path)"
  if [ -n "$num" ]; then
    path="/job/${path}/${num}/consoleText"
  else
    path="/job/${path}/lastBuild/consoleText"
  fi
  api_get "$path" | tail -n "$lines" | redact_log
}

cmd_jobs() {
  load_creds
  api_get "/api/json?tree=jobs[name]" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.stderr.write("错误：Jenkins 返回的不是 JSON\n")
    sys.exit(1)
jobs = [item["name"] for item in data.get("jobs", [])]
print("可见 job（%d 个）：" % len(jobs))
for name in jobs:
    print(" -", name)
'
}
