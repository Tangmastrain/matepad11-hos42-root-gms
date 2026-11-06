# MatePad 11（DBY-W09）恢复出厂后精简复原手册

> 用途：每次恢复出厂设置后，照此手册一步步执行即可复原全部精简配置。
> 无需回忆对话，所有命令可直接复制执行（PC 侧 Git Bash + adb）。
> 全程约 10 分钟（含 1 次重启）。
> 最后验证：2026-11-06 18:48

---

## 第 0 步：前提条件

1. 平板完成开机设置向导（跳过登录即可，进到桌面）
2. 开启开发者选项：设置 → 关于平板 → 连点"版本号"7 次
3. 开启 USB 调试：设置 → 系统和更新 → 开发人员选项 → USB 调试
4. 建议顺手关闭："允许 HiSuite 通过 HDB 连接设备"（该接口枚举报错会拖累 ADB）
5. 插 USB 线，弹出授权框勾"一律允许"

**⚠️ 常见坑：ADB 看不到设备**
- 下拉通知栏 → USB 连接方式 → 切换为"**传输文件**"（重置后默认仅充电，ADB 不通）
- 仍不行就拔插一次线；`adb kill-server && adb start-server` 后重试
- 设备序列号应为：`<你的设备序列号>`

**验证连接与 root：**
```bash
adb devices                      # 应显示 <你的设备序列号> device
adb shell getprop sys.boot_completed   # 应输出 1
adb shell su -c id               # 应输出 uid=0(root) ... context=u:r:magisk:s0
```

**重置后自动完成的事项（无需操作）：**
- Magisk root 保留（补丁在 boot 分区，不受恢复出厂影响）
- GMS 全套消失（gms12_systemless 模块在被清除的 /data 里）——先检查 `/data/app` 有无残留副本：
```bash
adb shell pm path com.google.android.gms
# 若输出 /data/app/... 则执行：adb shell pm uninstall com.google.android.gms
```

---

## 第 1 步：切换输入法（必须在第 2 步之前！）

重置后系统默认输入法是百度，直接卸载会导致无输入法可用。

```bash
# 启用并切换到 Celia 键盘（注意组件名是 latin.LatinIME，不是 ImeService）
adb shell ime enable com.huawei.ohos.inputmethod/com.android.inputmethod.latin.LatinIME
adb shell ime set com.huawei.ohos.inputmethod/com.android.inputmethod.latin.LatinIME
adb shell settings get secure default_input_method
# 必须输出：com.huawei.ohos.inputmethod/com.android.inputmethod.latin.LatinIME
```

---

## 第 2 步：批量卸载（21 项）

直接整段复制执行（每项失败会自动降级为停用，均为可恢复操作）：

```bash
for p in \
  com.huawei.search \
  com.huawei.intelligent \
  com.huawei.himovie \
  com.huawei.himovie.partner1 \
  com.huawei.himovie.partner2 \
  com.huawei.himovie.local \
  com.huawei.hmos.himovie.fa \
  com.sohu.sohuvideo.emplayer \
  com.tencent.qqlivehuawei \
  com.huawei.music \
  com.huawei.music.local \
  com.huawei.gameassistant \
  com.huawei.game.kitserver \
  com.huawei.magazine \
  com.huawei.ohos.suggestion \
  com.huawei.wallet \
  com.huawei.wallet.facard \
  com.huawei.hwpanpayservice \
  com.huawei.contacts \
  com.huawei.phoneservice \
  com.huawei.motionservice \
  com.baidu.input_huawei \
; do r=$(adb shell pm uninstall --user 0 $p 2>&1); if [ "$r" != "Success" ]; then r="$(adb shell pm disable-user --user 0 $p 2>&1) [fallback]"; fi; echo "$p => $r"; done
```

**说明：**
- `com.huawei.intelligent` = 智慧助手·今天的真正载体（名字里没有 search/assistant，别漏！）
- `com.unionpay.tsmservice`（银联 TSM）不用处理——/system/delapp 按需应用，用户 0 下本就未注册
- 末尾出现 `[fallback]` 表示该包是受保护 priv-app，已降级为停用，效果等同

## 第 3 步：批量停用（10 项 priv-app）

```bash
for p in \
  com.huawei.vassistant \
  com.huawei.hiai \
  com.huawei.recsys \
  com.huawei.pengine \
  com.huawei.searchservice \
  com.huawei.ohos.search \
  com.huawei.hidisk \
  com.huawei.android.thememanager \
  com.huawei.ohos.famanager \
  com.huawei.hicard \
  com.huawei.hwdiagnosis \
  com.huawei.hwdetectrepair \
  com.huawei.msdp \
; do echo "$p => $(adb shell pm disable-user --user 0 $p 2>&1)"; done
```

**说明：**
- `com.huawei.ohos.search` = 负一屏 FA 入口（与 search 是双包结构，两个都要处理）
- `com.huawei.msdp` = 智能感知平台（与已卸载的 motionservice 配对）

---

## 第 4 步：重建 Magisk 模块 debloat_stub3（5 个顽固进程）

这 5 个 APK 由 init/persistent 机制拉起，PM 层停用无效，必须用模块 stub。
（覆盖进程：nearby 软总线栈、hiaction、qdma，合计约 500MB 常驻）

### 4.1 在 PC 上准备模块目录（Git Bash）：

```bash
M=/tmp/debloat_stub3
rm -rf $M && mkdir -p "$M/system/app/HwNearby" "$M/system/app/HwAirlink" \
  "$M/system/app/iConnect" "$M/system/priv-app/HiAction" "$M/system/system_ext/app/QCC"
touch "$M/system/app/HwNearby/.replace" "$M/system/app/HwAirlink/.replace" \
  "$M/system/app/iConnect/.replace" "$M/system/priv-app/HiAction/.replace" \
  "$M/system/system_ext/app/QCC/.replace"
printf 'id=debloat_stub3\nname=Debloat Stub3 (nearby/hiaction/qdma)\nversion=v1.2\nversionCode=3\nauthor=WorkBuddy\ndescription=Empty-dir stubs for HwNearby HwAirlink iConnect HiAction QCC. Disable module to restore.\n' > "$M/module.prop"
```

> ⚠️ 关键经验：**Magisk magic mount 不挂载空目录**——目录里必须放 `.replace` 文件才会整体替换系统目录。

### 4.2 打包（python）：

```bash
python -c "
import zipfile, os
m = os.path.expandvars(r'%TEMP%') + r'\debloat_stub3'
out = os.path.expandvars(r'%TEMP%') + r'\debloat_stub3.zip'
if os.path.exists(out): os.remove(out)
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(m):
        for f in files + dirs:
            p = os.path.join(root, f)
            z.write(p, os.path.relpath(p, m).replace(chr(92),'/'))
print('ok')"
```

### 4.3 推送并安装：

```bash
MSYS_NO_PATHCONV=1 adb push "$TEMP/debloat_stub3.zip" /data/local/tmp/debloat_stub3.zip
MSYS_NO_PATHCONV=1 adb shell 'su -c "magisk --install-module /data/local/tmp/debloat_stub3.zip"'
# 应输出 "- Extracting module files / - Done"
```

---

## 第 5 步：重建 CPU 保底频率脚本

```bash
# PC 上生成（注意：不要用循环变量，转义会被吃掉；写 policy 头即可覆盖整簇）
printf '#!/system/bin/sh\n# originals: 300000/710400/844800\n# policy0 covers cpu0-3, policy4 covers cpu4-6\necho 403200 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq\necho 825600 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq\necho 960000 > /sys/devices/system/cpu/cpu7/cpufreq/scaling_min_freq\n' > "$TEMP/z-cpu-minfreq.sh"
MSYS_NO_PATHCONV=1 adb push "$TEMP/z-cpu-minfreq.sh" /data/local/tmp/z-cpu-minfreq.sh
MSYS_NO_PATHCONV=1 adb shell 'su -c "cp /data/local/tmp/z-cpu-minfreq.sh /data/adb/service.d/z-cpu-minfreq.sh; chmod 755 /data/adb/service.d/z-cpu-minfreq.sh; sh /data/adb/service.d/z-cpu-minfreq.sh; for c in 0 4 7; do echo cpu\$c=\$(cat /sys/devices/system/cpu/cpu\$c/cpufreq/scaling_min_freq); done"'
# 应输出 cpu0=403200 cpu4=825600 cpu7=960000
```

> 坑：脚本里不要用 `(sleep 30; ...)&` 后台写法——子 shell 会随会话被杀；也不要用 `$c` 循环变量——多层转义会吃掉它。

---

## 第 6 步：安装 Magisk 管理器 App + VLC（可选）

```bash
# Magisk 管理器（工作区有安装包，没有就去 GitHub 镜像下载 Magisk-v27.0.apk）
adb install -r "<本机路径>/Magisk-v27.0.apk"

# VLC 3.7.1（官方 APK）
adb install -r "$TEMP/vlc.apk"   # 无缓存则先从 get.videolan.org/vlc-android/ 下载 arm64-v8a 版
```

---

## 第 7 步：重启并验证

```bash
MSYS_NO_PATHCONV=1 adb reboot
sleep 55 && MSYS_NO_PATHCONV=1 adb wait-for-device && adb shell getprop sys.boot_completed
sleep 35   # 等 CPU 脚本和系统稳定
```

**验证清单（一条命令）：**
```bash
adb shell '
echo "1.进程扫描（应零命中）";
ps -A -o NAME | grep -E "fastapp|vassistant|hiai|nearby|airlink|iconnect|hiaction|qdma|gms|vending|himovie|music|wallet|magazine|suggestion|gameassistant|kitserver|recsys|pengine|searchservice|hidisk|thememanager|famanager|hicard|hwdiag|detectrepair|contacts|phoneservice|msdp|motionservice|intelligent|ohos.search";
echo "--扫描结束";
echo "2.模块挂载（目录应为空）";
ls /system/app/HwAirlink/ /system/app/HwNearby/ /system/app/iConnect/ 2>&1 | head -6;
echo "3.CPU频率（应 403200/825600/960000）";
su -c "for c in 0 4 7; do echo cpu\$c=\$(cat /sys/devices/system/cpu/cpu\$c/cpufreq/scaling_min_freq); done";
echo "4.输入法（应为 Celia）";
settings get secure default_input_method;
echo "5.内存";
dumpsys meminfo | grep -E "Free RAM|Used RAM"'
```

**预期结果**：进程扫描零命中；三个 APK 目录为空；CPU 403200/825600/960000；输入法 Celia；应用进程占用约 2.0GB（对比原厂 ~2.6GB+）。

---

## 回滚速查

```bash
# 恢复单个被卸载的包
adb shell cmd package install-existing <包名>
# 恢复单个被停用的包
adb shell pm enable <包名>
# 恢复模块 stub 的 5 个 APK：Magisk 管理器禁用 debloat_stub3 → 重启
# 恢复 CPU 频率：删除 /data/adb/service.d/z-cpu-minfreq.sh 并把 min 写回 300000/710400/844800
```

## 🔴 永远不动的包（核心）

captiveportallogin（校园网）、iaware/powergenie（功耗）、systemmanager（管家）、hwid/hff/pushagent/gateway/ca（HMS 底座）、securityserver/securitymgr/coauthservice/behaviorauth（安全）、hwbluetoothpencilmanager/stylus.floatmenu/hiwrite/sharedfeature.stylus（手写笔）、蓝牙/电话/短信框架、cellbroadcastservice（地震预警）、providers 全系、appmarket、Celia 键盘（ohos.inputmethod）、图库（photos）、launcher/systemui/systemserver、所有 overlay 与 /apex 组件、featurelayer.featureframework。

完整分析见《matepad11-精简清单-20261106.md》与《matepad11-精简清单-流畅性排行版.md》。
