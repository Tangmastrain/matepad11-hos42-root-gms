#!/usr/bin/env bash
# post-reset-restore.sh -- MatePad 11 (DBY-W09) factory-reset debloat restore.
#
# Run this on a PC (Git Bash) with adb connected to a freshly reset tablet
# that has USB debugging enabled and Magisk root (patched boot survives reset).
# Full background: docs/matepad11-重置后复原手册.md
#
# Steps performed:
#   1. Switch default IME to Celia keyboard   (MUST run before uninstalling Baidu IME)
#   2. Uninstall user-0 packages              (promo/content apps)
#   3. Disable user-0 packages                (protected priv-apps)
#   4. Build + install debloat_stub3 module   (init/persistent vendor processes)
#   5. Install CPU min-freq boot script       (/data/adb/service.d/z-cpu-minfreq.sh)
#   6. Reboot + verify
set -u
ADB="adb"
say() { printf '\n==> %s\n' "$*"; }

# ---------- 0. preflight ----------
say "Preflight: device + root"
$ADB get-state >/dev/null 2>&1 || { echo "ERROR: no adb device"; exit 1; }
[ "$($ADB shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] || { echo "ERROR: device not booted"; exit 1; }
$ADB shell su -c id | grep -q "uid=0" || { echo "ERROR: no root (su)"; exit 1; }

# ---------- 1. input method (CRITICAL ORDER) ----------
say "Step 1: switch default IME to Celia keyboard (before removing Baidu IME)"
$ADB shell ime enable  com.huawei.ohos.inputmethod/com.android.inputmethod.latin.LatinIME
$ADB shell ime set     com.huawei.ohos.inputmethod/com.android.inputmethod.latin.LatinIME
cur=$($ADB shell settings get secure default_input_method | tr -d '\r')
case "$cur" in
  com.huawei.ohos.inputmethod*) echo "OK: default IME = $cur" ;;
  *) echo "ERROR: IME switch failed (current: $cur). Aborting to avoid no-IME lockout."; exit 1 ;;
esac

# ---------- 2. uninstall batch ----------
say "Step 2: uninstall user-0 packages"
UNINSTALL="
com.huawei.search
com.huawei.intelligent
com.huawei.himovie
com.huawei.himovie.partner1
com.huawei.himovie.partner2
com.huawei.himovie.local
com.huawei.hmos.himovie.fa
com.sohu.sohuvideo.emplayer
com.tencent.qqlivehuawei
com.huawei.music
com.huawei.music.local
com.huawei.gameassistant
com.huawei.game.kitserver
com.huawei.magazine
com.huawei.ohos.suggestion
com.huawei.wallet
com.huawei.wallet.facard
com.huawei.hwpanpayservice
com.huawei.contacts
com.huawei.phoneservice
com.huawei.motionservice
com.baidu.input_huawei
"
for p in $UNINSTALL; do
  r=$($ADB shell pm uninstall --user 0 "$p" 2>&1 | tr -d '\r')
  if [ "$r" != "Success" ]; then
    r=$($ADB shell pm disable-user --user 0 "$p" 2>&1 | tr -d '\r')
    echo "  $p => $r [fallback-disable]"
  else
    echo "  $p => Success"
  fi
done
# NOTE: com.unionpay.tsmservice lives in /system/delapp and is not registered
# for user 0 on a fresh reset -- nothing to do.

# ---------- 3. disable batch ----------
say "Step 3: disable protected priv-apps"
DISABLE="
com.huawei.vassistant
com.huawei.hiai
com.huawei.recsys
com.huawei.pengine
com.huawei.searchservice
com.huawei.ohos.search
com.huawei.hidisk
com.huawei.android.thememanager
com.huawei.ohos.famanager
com.huawei.hicard
com.huawei.hwdiagnosis
com.huawei.hwdetectrepair
com.huawei.msdp
"
for p in $DISABLE; do
  echo "  $p => $($ADB shell pm disable-user --user 0 "$p" 2>&1 | tr -d '\r')"
done

# ---------- 4. debloat_stub3 module ----------
say "Step 4: build + install debloat_stub3 module"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
"$HERE/module/debloat_stub3/build.sh"
MODZIP="$HERE/module/debloat_stub3/debloat_stub3.zip"
$ADB push "$MODZIP" /data/local/tmp/debloat_stub3.zip >/dev/null
$ADB shell 'su -c "magisk --install-module /data/local/tmp/debloat_stub3.zip"' | tail -2

# ---------- 5. CPU min-freq boot script ----------
say "Step 5: install CPU min-freq boot script"
$ADB push "$HERE/scripts/z-cpu-minfreq.sh" /data/local/tmp/z-cpu-minfreq.sh >/dev/null
$ADB shell 'su -c "cp /data/local/tmp/z-cpu-minfreq.sh /data/adb/service.d/z-cpu-minfreq.sh && chmod 755 /data/adb/service.d/z-cpu-minfreq.sh && sh /data/adb/service.d/z-cpu-minfreq.sh && echo freq-applied"'

# ---------- 6. reboot + verify ----------
say "Step 6: reboot and verify (rerun with --verify after reboot)"
if [ "${1:-}" = "--verify" ]; then
  $ADB shell '
    echo "[process scan - expect zero hits]";
    ps -A -o NAME | grep -E "fastapp|vassistant|hiai|nearby|airlink|iconnect|hiaction|qdma|gms|vending|himovie|music|wallet|magazine|suggestion|gameassistant|kitserver|recsys|pengine|searchservice|hidisk|thememanager|famanager|hicard|hwdiag|detectrepair|contacts|phoneservice|msdp|motionservice|intelligent|ohos.search";
    echo "[module mount - expect empty dirs]";
    ls /system/app/HwAirlink/ /system/app/HwNearby/ /system/app/iConnect/ 2>&1 | head -6;
    echo "[cpu min freq - expect 403200/825600/960000]";
    su -c "for c in 0 4 7; do echo cpu\$c=\$(cat /sys/devices/system/cpu/cpu\$c/cpufreq/scaling_min_freq); done";
    echo "[default IME - expect Celia]";
    settings get secure default_input_method;
    echo "[memory]";
    dumpsys meminfo | grep -E "Free RAM|Used RAM"'
else
  $ADB reboot
  echo "Rebooting. After boot completes run:  $0 --verify"
fi
