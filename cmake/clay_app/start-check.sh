#!/usr/bin/env bash
# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Starts a packaged app (clay_app_package) the way a machine without Qt
# would, and fails if it does not come up: start-check.sh <executable>
#
# The environment is emptied - no Qt on PATH, no DYLD_*/LD_* paths, no
# QT_PLUGIN_PATH or QML_IMPORT_PATH - so the app has only what its package
# carries. QT_QPA_PLATFORM=minimal is clay_app's start check: any QML warning
# exits 1, and a Main.qml that quits on the minimal platform exits 0.
# Every library the app loads has to come from the package or the system.
set -uo pipefail

exe=$1
log=$(mktemp)
# The package's path with symlinks resolved (pwd -P), as the loader reports
# what it loads: on macOS /tmp and /var are symlinks into /private
case "$(uname -s)" in
    Darwin) trace="DYLD_PRINT_LIBRARIES=1"; pkg=$(cd "$(dirname "$exe")/../.." && pwd -P) ;;
    *) trace="LD_DEBUG=libs"; pkg=$(cd "$(dirname "$exe")/.." && pwd -P) ;;
esac
env -i HOME="$HOME" PATH=/usr/bin:/bin QT_QPA_PLATFORM=minimal "$trace" \
    "$exe" > "$log" 2>&1
code=$?

case "$(uname -s)" in
    Darwin) loaded=$(sed -n 's/^dyld\[[0-9]*\]: <[^>]*> //p' "$log") ;;
    *) loaded=$(sed -n 's/.*calling init: //p' "$log") ;;
esac
foreign=$(printf '%s\n' "$loaded" | grep -v -e "^$pkg/" -e '^/System/' -e '^/usr/lib/' \
          -e '^/lib' -e '^/usr/lib64/' -e '^$' || true)

grep -v -e '^dyld\[' -e 'calling init' -e '^ *[0-9]*:' "$log"
echo "exit code: $code"
echo "libraries loaded: $(printf '%s\n' "$loaded" | grep -c .)"
if [ -n "$foreign" ]; then
    echo "loaded from outside the package:"
    printf '%s\n' "$foreign"
    code=1
fi
rm -f "$log"
exit $code
