#!/system/bin/sh
# 把 KernelSU 液态玻璃底栏模板装进目标 Android 工程。
#
# 用法:
#   sh install-glass-ui.sh <project-root> <target-package> [subdir]
# 例:
#   sh install-glass-ui.sh /data/local/tmp/eta/MyApp com.example.myapp.ui.glass
#
# 只做两件事：复制 assets/ksu-glass-ui/*.kt，并把模板里的源包名
# com.eta.privacydot.ui.ksu 重写为 <target-package>（package 与 import 两处）。
# 刻意只用 POSIX 语法：Android 的 sh 是 mksh，没有 BASH_SOURCE / pipefail。

set -eu

if [ $# -lt 2 ]; then
  echo "usage: sh install-glass-ui.sh <project-root> <target-package>" >&2
  exit 2
fi

PROJECT="$1"
PKG="$2"
SKILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$SKILL_ROOT/assets/ksu-glass-ui"
OLD_PKG="com.eta.privacydot.ui.ksu"

[ -d "$SRC" ] || { echo "assets missing: $SRC" >&2; exit 1; }

# Kotlin 源码根目录：优先 app/src/main/kotlin，退到 app/src/main/java
BASE=""
for cand in "$PROJECT/app/src/main/kotlin" "$PROJECT/app/src/main/java"; do
  if [ -d "$cand" ]; then BASE="$cand"; break; fi
done
[ -n "$BASE" ] || { echo "no Kotlin source root under $PROJECT/app/src/main" >&2; exit 1; }

DEST="$BASE/$(echo "$PKG" | tr '.' '/')"
mkdir -p "$DEST"

count=0
for f in "$SRC"/*.kt; do
  name="$(basename "$f")"
  sed "s|^package $OLD_PKG\$|package $PKG|; s|^import $OLD_PKG\.|import $PKG.|" "$f" > "$DEST/$name"
  count=$((count + 1))
done

echo "installed $count files -> $DEST"
echo
echo "还需手动做两件事："
echo "  1) 在 gradle 里加 miuix-ui / miuix-blur / miuix-icons 依赖"
echo "     （见 references/integration-walkthrough.md 第 1 节）"
echo "  2) 按 references/integration-walkthrough.md 接线"
echo "     双层 backdrop + Scaffold + pager + 底栏两形态"
