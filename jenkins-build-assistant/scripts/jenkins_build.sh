#!/bin/bash
# Compatibility entry. Platform behavior is in ios.sh, android.sh, harmony.sh.
#   jenkins_build.sh status            -> ios.sh status
#   jenkins_build.sh ios jobs          -> ios.sh jobs
#   jenkins_build.sh android channels  -> android.sh channels
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
platform="${1:-ios}"
case "$platform" in
  ios|android|harmony)
    shift || true
    exec bash "$DIR/${platform}.sh" "$@"
    ;;
  *)
    exec bash "$DIR/ios.sh" "$@"
    ;;
esac
