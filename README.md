# MatePad 11 (DBY-W09) 鸿蒙平板精简与复原工程

针对华为 MatePad 11（DBY-W09，HarmonyOS 4.2.0.213，Magisk 27 root）的系统精简工程。
目标：移除厂商推广、冗余服务与常驻后台，最大化流畅度与可用内存，同时保持校园网认证、
手写笔、蓝牙耳机等核心硬件功能完好，且**全部操作可一键回滚**。

> 2026-11-06 项目重心从 GMS 兼容转向系统精简（恢复出厂后重建）。旧 GMS 时代组件
> （checkin-guard / gmscompat / imeifix）已从工作区移除，可在 git 历史中找到；
> 刷机与 root 过程记录归档于 [docs/legacy-rebrand-and-root-guide.md](docs/legacy-rebrand-and-root-guide.md)。

## 项目目标

1. **流畅性优先**：清除常驻后台（推广/协同/语音/AI 引擎），降低 ZRAM 压缩交换压力
2. **功能保留**：校园网 Portal 认证、M-Pencil 手写笔、蓝牙音频、Celia 输入法、图库播放
3. **完全可逆**：所有修改通过 `pm uninstall --user 0` / `pm disable-user` / Magisk 模块实现，禁止破坏系统分区
4. **可复现**：恢复出厂后按手册/脚本可在 10 分钟内复原全部配置

## 目录结构

```
├── README.md                      # 本文件
├── docs/                          # 全部分析与操作文档
│   ├── matepad11-精简清单-20261106.md       # 250 个系统包全量分类与风险标注
│   ├── matepad11-精简清单-流畅性排行版.md    # 按流畅性提升排序的清单（S/A/B/C 级）
│   ├── matepad11-操作台账-20261106.md       # 已执行操作的全量台账 + 回滚命令
│   ├── matepad11-重置后复原手册.md           # 恢复出厂后 10 分钟复原手册（逐步命令）
│   └── legacy-rebrand-and-root-guide.md     # [归档] EDL 刷机与 root 过程记录
├── module/
│   └── debloat_stub3/             # Magisk 模块：stub 5 个 init/persistent 顽固进程
│       ├── module.prop            #   模块描述
│       └── build.sh               #   PC 端构建脚本（python 打包 zip）
└── scripts/
    ├── post-reset-restore.sh      # 一键复原脚本（驱动 adb 完成全部步骤）
    └── z-cpu-minfreq.sh           # CPU 保底频率提升（/data/adb/service.d 开机脚本）
```

## 主要模块及职责

### 1. `scripts/post-reset-restore.sh` — 一键复原主脚本
在 PC 端运行，通过 adb 驱动刚重置的平板完成全部精简：
- **前置检查**：设备连接、开机完成、root 可用
- **输入法切换**：默认 IME 切到 Celia 键盘（必须先于卸载百度输入法，否则输入法空窗）
- **批量卸载**（21 项）：负一屏双包 + 智慧助手今天、华为视频 ×5、搜狐/腾讯嵌入版、
  华为音乐 ×2、游戏助手/中心、杂志锁屏、推荐卡片、钱包系列、联系人、我的华为、手势服务
- **批量停用**（13 项）：小艺、HiAI、recsys、pengine、搜索服务、云盘、主题、服务中心、
  HiCard、智能检测 ×2、msdp（受保护 priv-app 拒绝卸载时自动降级 disable-user）
- **模块安装**：调用 `module/debloat_stub3/build.sh` 构建并刷入
- **CPU 脚本**：部署开机保底频率脚本
- **重启验证**：`--verify` 参数执行五项健康检查

### 2. `module/debloat_stub3` — 顽固进程 stub 模块
5 个 APK（HwNearby / HwAirlink / iConnect / HiAction / QCC）由 init 与 persistent 机制
拉起，PM 层停用/卸载均无效。本模块以"空目录 + `.replace` 标记"systemless 地替换这些
APK，消除约 500MB 常驻进程（含分布式软总线栈）。禁用模块即整体还原。

### 3. `scripts/z-cpu-minfreq.sh` — CPU 保底频率
小核 300→403MHz、大核 710→826MHz、超大核 845→960MHz（写 policy 头覆盖整簇）。
骁龙 865 的 max 已在硬件表顶格，无法超频。部署到 `/data/adb/service.d/` 开机自启。

## 技术要点（踩坑记录）

1. **Magisk magic mount 不挂载空目录**：stub 系统 APK 时目录内必须放 `.replace` 标记文件
2. **进程名 ≠ 包名**：`com.huawei.nearby` 进程的代码实际由 HwAirlink/iConnect 加载
   （共享 `vendor_dsoftbus` UID），只删 HwNearby 无效
3. **受保护 priv-app 拒绝 `pm uninstall`**：用 `pm disable-user --user 0` 效果等同且可恢复
4. **负一屏是四包结构**：`search`（主程序）、`ohos.search`（FA 入口）、`searchservice`
   （后台引擎）、`intelligent`（智慧助手·今天页面本体）——缺一个都会残留
5. **输入法卸载顺序**：重置后默认输入法是百度，必须先 `ime set` 切到 Celia 再卸载
6. **service.d 脚本写法**：不要用 `(sleep N; ...)&` 后台写法（子 shell 随会话被杀）；
   不要用 shell 循环变量（多层引号转义会吃掉变量），直接写 policy 头三行
7. **GMS /data 残留**：禁用 systemless 模块只移除 system 挂载，Play 自更新写入
   `/data/app` 的 GmsCore 副本需单独 `pm uninstall`
8. **Git Bash + adb**：需要 `MSYS_NO_PATHCONV=1` 防止 `/data/...` 路径被转换

## 当前状态（2026-11-06）

- ✅ 系统重置后全量精简已复原并通过重启持久性验证（S/A/B/C 级全覆盖，约 40+ 组件）
- ✅ 常驻内存从原厂 ~2.6GB 降至 ~2.0GB，ZRAM 压缩交换下降约 10%
- ✅ CPU 保底频率 403/826/960MHz 开机自动生效
- ✅ 核心功能完好：校园网认证、手写笔、蓝牙、图库视频播放、Celia 输入法
- ⏳ 待定：VLC 重装（按需）；Zygisk/Shamiko/LSPosed 体系（仅当需要 root 隐藏时重装）

## 使用方法

```bash
# 恢复出厂并完成设置向导 + USB 调试后，PC 端执行：
./scripts/post-reset-restore.sh            # 全部精简
# 重启完成后：
./scripts/post-reset-restore.sh --verify   # 五项验证
```

单步操作、风险等级与逐项影响分析见 `docs/` 下四份文档。

## License

见 [LICENSE](LICENSE)。
