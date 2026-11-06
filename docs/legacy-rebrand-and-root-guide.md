# MatePad 11 (2021, DBY-W09): HOS 2 Global → HarmonyOS 4.2.0.208 China, unlocked bootloader kept, APatch root, real Google Play services

A step-by-step record of what worked on **one** Huawei MatePad 11 2021 (DBY-W09, Snapdragon 865, UFS). It is not
a one-click tool, and it was done once, on one unit. Read the whole document before you start.

> **Warning.** This uses Qualcomm EDL, rewrites the partition table (GPT) and the region record (oeminfo), and
> flashes every partition by hand. One wrong sector number can hard-brick the tablet. **All user data is wiped.**
> Take the full EDL backup in [step 2](#2-full-backup-in-edl), keep it on two disks, and do not skip the
> read-back checks. You do this at your own risk.

This builds on **faxcon's** XDA guide
["Comprehensive MatePad 11 2021 (DBY-W09) Rebrand, Update, and Root Guide"](https://xdaforums.com/t/comprehensive-matepad-11-2021-dby-w09-rebrand-update-and-root-guide.4789106/)
and on **scoolo** (4PDA), who found the method. The difference here: I went from **HOS 2.0.0.278 Global (C432)**
straight to **HOS 4.2.0.208 China (C00)** without first installing the HOS 2 China dload package. That needs a new
GPT, which this repository generates from the 4.2 package itself and checks against the device.

> **Latest result, 28 Oct 2026 — application access restored with a separate local compatibility module.**
> Play Store downloads, Maps search/tiles and Photos local gallery/viewer pass the current device tests and
> reboot test. The same registered identity still has `uncertified_status=3`. The [module](gmscompat/)
> adapts three inspected application-side enforcement gates; it does not confer certification or Play Integrity.
> Removing it and rebooting reproduced the block. A new observation beyond 25 hours is **still pending**.
> App-version updates require revalidation. See the [implementation and control tests](reports/2026-10-28-app-compatibility.md).
>
> **Earlier on 28 Oct 2026 — the block returned after more than 25 hours.** The same registered GSF identity
> now has `uncertified_status=3`. Checkin is still successful and the guard is running. Play Store, Photos and
> Maps again open `UncertifiedDeviceActivity`. The guard protects against missed Checkins; it does not prevent
> this certification denial. See the [recurrence investigation](reports/2026-10-28-recurrence.md).
>
> **Historical result, 26 Oct 2026 — the block was temporarily recovered on this unit.** The existing
> [IMEI fix](#114-checkin-fails-unknown-is-not-a-valid-imei) restored Checkin, but the old GSF identity still
> received `uncertified_status=3`. After backing up its Checkin state, obtaining a new identity through Google's
> normal Checkin exchange, and registering that identity at Google's official page, Play Store, Maps and Photos
> worked again, including after reboot. GMS reports `shouldAllowGmsFunctionality=true`, `isProvisional=false`.
>
> [The recovery report](reports/2026-10-26-gsf-recovery.md) records the tests, rollback and remaining limits.
> This is **not OEM certification or a Play Integrity pass**. The subsequent test past 25 hours **failed**.
> An optional [Checkin guard](checkin-guard/) is installed on this unit to log health and request a normal Checkin
> if the last success is over 18 hours old. Keep the IMEI fix enabled; do not routinely clear GSF/GMS data or rotate IDs.

## Contents

- [Result](#result)
- [What you need](#what-you-need)
- [Downloads](#downloads)
- [PC setup](#pc-setup)
- [1. Get to HarmonyOS 2](#1-get-to-harmonyos-2)
- [2. Full backup in EDL](#2-full-backup-in-edl)
- [3. Unlock the bootloader](#3-unlock-the-bootloader)
- [4. Prepare the 4.2 images](#4-prepare-the-42-images)
- [5. Build the new GPT](#5-build-the-new-gpt)
- [6. Build the new oeminfo](#6-build-the-new-oeminfo)
- [7. Write GPT and oeminfo in EDL](#7-write-gpt-and-oeminfo-in-edl)
- [8. Flash HarmonyOS 4.2 in fastboot](#8-flash-harmonyos-42-in-fastboot)
- [9. First boot](#9-first-boot)
- [10. Root with APatch](#10-root-with-apatch)
- [11. Google Play services](#11-google-play-services)
- [12. After setup](#12-after-setup)
- [Troubleshooting](#troubleshooting)
- [Going back](#going-back)
- [Scripts in this repository](#scripts-in-this-repository)

## Result

- HarmonyOS 4.2.0.208 (C00E100), Android 12 / API 31. The China firmware includes Turkish, English and other
  languages; pick yours on the first setup screen.
- Bootloader unlocked (orange state). `fastboot oem edl` still works, so EDL stays reachable for recovery.
- Root with APatch (build 11282) and the meta-magic_mount-rs metamodule.
- Real Google Play services, Google Services Framework and Play Store installed as privileged system apps through
  a systemless module built from MindTheGapps 12.1. **Not microG.** The system partition is not modified.

What I checked with adb (not just "it installed"):

| Item | Status |
|---|---|
| Play services / Play Store as priv-app, updating themselves (GMS 26.41, Play Store 53.6) | Installed and updating |
| Google account sign-in, ~50 apps installed from Play Store | Worked on the first day |
| Play Store, Google Photos, Maps | Restored on 28 Oct with the [local application module](gmscompat/), including Store download and reboot/control tests. Long-duration observation pending; see [results and limits](reports/2026-10-28-app-compatibility.md). |
| Google app / Drive (26 Oct 2026 after recovery) | Main interfaces open after clearing the old activity task. Search execution, file download/upload and long-term behavior are not fully tested. |
| Checkin with Play services 26.41 | Fails with `"unknown" is not a valid IMEI` until the [IMEI fix](#114-checkin-fails-unknown-is-not-a-valid-imei) is installed; succeeds after it |
| FCM push connection (`mtalk.google.com:5228` connected) | Works (also on 26 Oct 2026, while the apps are blocked) |
| Contacts and calendar sync | Works after [the permission script](#113-runtime-permissions) |
| Netflix DRM | Widevine **L1** (Netflix reports `WIDEVINE_L1`, L1 certificates provisioned) |
| Netflix resolution | **720p measured** (1280×720 buffer, secure H.264 decoder) in the first minute of one title. Longer playback not tested. Prime Video and HBO Max not measured. The panel is 2560×1600, so 4K output is not possible on this tablet anyway. |
| Play Protect certification | **No OEM certification established.** The current Google supported-device list has no DBY-W09 match. Working Google apps do not prove certification. |
| Banking apps / Play Integrity | Not tested. Expect some to refuse to run. |
| Huawei pen (M-Pencil) | Pairs and connects |
| Huawei Smart Magnetic Keyboard | Not working on my unit, but it was already broken before the update, so I can't say whether 4.2 is the cause. |

## What you need

- MatePad 11 2021, model **DBY-W09** (Wi-Fi, Snapdragon 865). Other models (DBY-W09**S** is the Global name of
  the same hardware, see oeminfo below; DBY2, DBR, LTE versions) are **different**: do not use these files on them.
- Windows 10/11 PC (Linux works for edl and fastboot too, but the commands here are for Windows), a USB-C **data**
  cable plugged directly into the PC (no hub).
- About **40 GB** free disk space: ~13 GB EDL backup, ~5 GB firmware zips, ~12 GB extracted images.
- Battery above 60 %.
- A Google account, and some patience.

## Downloads

Get every file from its original source and check the hash. Do not use re-uploads from file-hosting sites.

| What | Where | Check |
|---|---|---|
| Android platform-tools (adb, fastboot) | <https://developer.android.com/tools/releases/platform-tools> | — |
| Python 3.10+ | <https://www.python.org/downloads/> (tick "Add to PATH") | — |
| bkerler/edl (Qualcomm EDL client) | <https://github.com/bkerler/edl> (I used commit `1cda1a6`) | — |
| Zadig (WinUSB driver for EDL) | <https://zadig.akeo.ie/> or `edl/Drivers/Windows` in the edl repo | — |
| HiSuite (only for the downgrade to HOS 2) | <https://consumer.huawei.com/en/support/hisuite/> | — |
| Firehose loader `dbyprog_emmc_firehose` | Google Drive folder linked in faxcon's guide | SHA-256 `a0e08a0a26b1356e04fb3b3097c70237a2e3e0861dbd1a99cafbab4f5adc7c9d`, 697 648 bytes, Huawei-signed (CBG attest root) |
| Unlock ABL `abl_hw865870unlock.elf` | Same folder | SHA-256 `552e96d2565627563b7f2b072f720efd048abdf11fa050959aec55e7d3f0b79d`, 602 112 bytes, Huawei-signed |
| HOS 4.2.0.208 base package `update_full_base.zip` | [Huawei CDN](http://update.dbankcdn.com/download/data/pub_13/HWHOTA_hota_900_9/77/v3/v9yZI3GeRSCCVYPPG7T_5A/full/update_full_base.zip) | 4 788 537 569 bytes, SHA-256 `65C6039F24F9BA9C040E1BA9CF050E1720BF37F9AB293DE7B16E7D004BC02213` |
| cust package `update_full_cust_DBY-W09_all_cn.zip` | [Huawei CDN](http://update.dbankcdn.com/download/data/pub_13/HWHOTA_hota_900_9/9b/v3/EcY-XW4RTNOY1DrkyHKRqw/full/update_full_cust_DBY-W09_all_cn.zip) | 379 357 bytes, SHA-256 `4D5C9D48942C92161776DCD6B2A82CC623BC7C5720AA9E5E23A1A5F05C6554C9` |
| preload package `update_full_preload_DBY-W09_all_cn_R1.zip` | [Huawei CDN](http://update.dbankcdn.com/download/data/pub_13/HWHOTA_hota_900_9/94/v3/Wbkd1I4_SWOtYB4jX0ycDg/full/update_full_preload_DBY-W09_all_cn_R1.zip) | Check against `filelist.xml` in the same folder |
| APatch app | <https://github.com/bmax121/APatch/releases> (I used build 11282) | — |
| meta-magic_mount-rs metamodule | <https://github.com/Tools-cx-app/meta-magic_mount-rs/releases> (I used `magic_mount_rs-4.0.12-941-arm64.zip`) | — |
| MindTheGapps 12.1.0 arm64 | [GitHub release](https://github.com/MindTheGapps/12.1.0-arm64/releases/download/MindTheGapps-12.1.0-arm64-20231025_200924/MindTheGapps-12.1.0-arm64-20231025_200924.zip) | SHA-256 `8df6bc0b19660ca1586f0a65d3c0eb21554d6bf65d78fd1cd94a30df457cdc70` (the module script checks it) |

Each Huawei CDN folder also has a `filelist.xml` (replace the file name at the end of the URL with
`filelist.xml`) that lists the official SHA-256 of every package. I found these links through the firmware
database at pro-teammt.ru (search for DBY-W09). Use `certutil -hashfile <file> SHA256` in Windows to check a hash.

## PC setup

1. Unzip platform-tools to e.g. `C:\platform-tools` and add it to `PATH`, or run adb/fastboot with the full path.
   Check: `adb version`, `fastboot --version`.
2. Install Python. Check: `python --version`.
3. Get bkerler/edl: `git clone https://github.com/bkerler/edl` (or download the ZIP), then
   `python -m pip install -r edl\requirements.txt`. Below, `edl` means `python C:\path\to\edl\edl.py`.
4. Clone this repository next to it: `git clone https://github.com/serkanvela/matepad11-hos42-root-gms`.
5. Make one working folder, e.g. `C:\mp11\`, and put the firehose, the unlock ABL and the firmware zips in it.
6. Close HiSuite completely (also `hwtransport.exe` in Task Manager); it grabs the ADB interface.

In the commands below:

```
set FH=C:\mp11\dbyprog_emmc_firehose
edl <command> --memory=ufs --loader=%FH%
```

Every `edl` call needs `--memory=ufs --loader=%FH%`. I leave it out below to keep the lines short.

## 1. Get to HarmonyOS 2

On HarmonyOS 3.x Global, `adb reboot edl` is ignored and `fastboot oem edl` returns "Command not allowed"
(tested on 3.0.0.216). EDL is only reachable from software on HarmonyOS 2.

- Use HiSuite → "Switch to other version" / system recovery to go back to HarmonyOS 2 (I ended up on
  **2.0.0.278 C432**). **This wipes the tablet**, so back up first (HiSuite backup, photos, etc.).
- If HiSuite offers no older version, faxcon's guide mentions HiSuite Proxy. I didn't need it.
- On HOS 2, enable Developer options (tap the build number 7 times) and USB debugging. Accept the RSA prompt.

## 2. Full backup in EDL

This is the most important step. Without it there is no way back.

1. `adb reboot edl`. The screen stays black. Device Manager shows **QUSB_BULK_CID:0412** (or "QHSUSB_BULK").
2. First time only: open Zadig → Options → List All Devices → select that device → driver **WinUSB** →
   Install Driver.
3. Read every partition except userdata, and the partition tables:

```
edl rl C:\mp11\backup --skip=userdata --genxml
```

   This takes a while (~13 GB, 73 partitions on my unit). It writes one folder per LUN with all partitions and
   `gpt_mainN.bin` / `gpt_backupN.bin` for LUN 0–5.

4. Separately, so you have them at hand:

```
edl r oeminfo C:\mp11\backup\oeminfo_hos2.bin
edl r abl C:\mp11\backup\abl_stock.bin
```

5. Make a hash list and copy the whole `backup` folder to a second disk:

```
cd C:\mp11\backup
certutil -hashfile oeminfo_hos2.bin SHA256
```

   (or `Get-ChildItem -Recurse -File | Get-FileHash` in PowerShell, saved to `SHA256SUMS.txt`).

6. `edl reset` to reboot.

> **If the device stops answering in EDL** (it can happen after an erase): hold **Power + Volume Up + Volume
> Down** until it restarts, then hold **Volume Down** while connected to get into fastboot.

## 3. Unlock the bootloader

1. `adb reboot edl`
2. Write the Huawei-signed unlock ABL:

```
edl w abl C:\mp11\abl_hw865870unlock.elf
edl reset
```

3. Hold **Volume Down** while it restarts (USB connected) to enter fastboot. Check:

```
fastboot getvar unlocked          -> unlocked: yes
fastboot oem lock-state info
```

4. `fastboot reboot`. From now on, **never flash the stock `ABL` image from a package**: it would lock the
   bootloader again, and on 4.2 you may not get back into EDL to undo it. `flashplan.py` skips ABL for this reason.

## 4. Prepare the 4.2 images

1. Check the three zips against the hashes above.
2. Each zip contains one `UPDATE.APP` (Huawei's container). Extract them into separate folders:

```
mkdir C:\mp11\app\base C:\mp11\app\cust C:\mp11\app\preload
tar -xf update_full_base.zip -C C:\mp11\app\base UPDATE.APP
tar -xf update_full_cust_DBY-W09_all_cn.zip -C C:\mp11\app\cust UPDATE.APP
tar -xf update_full_preload_DBY-W09_all_cn_R1.zip -C C:\mp11\app\preload UPDATE.APP
```

3. Extract the partition images from each `UPDATE.APP`:

```
python scripts\updateapp.py C:\mp11\app\base\UPDATE.APP                       (list only)
python scripts\updateapp.py C:\mp11\app\base\UPDATE.APP    C:\mp11\img\base
python scripts\updateapp.py C:\mp11\app\cust\UPDATE.APP    C:\mp11\img\cust
python scripts\updateapp.py C:\mp11\app\preload\UPDATE.APP C:\mp11\img\preload
```

   Names are cut at 16 characters (`ERECOVERY_RAMDIS`, `VBMETA_HW_PRODUC`). `SUPER` comes in two sparse parts,
   `SUPER_0.img` and `SUPER_1.img`. `EFI_0.img` in `img\base` is the 4.2 GPT template used in the next step.

## 5. Build the new GPT

### Why

Several 4.2 images do not fit the HOS 2 Global partition layout:

| Image | Needs | Old partition |
|---|---|---|
| `VERSION` (cust, sparse) | 576 MiB | 32 MiB |
| `RECOVERY_RAMDISK`, `ERECOVERY_RAMDISK` | 36 MiB | 32 MiB |

faxcon's route avoids this by installing the HOS 2 China dload package first, which rewrites the GPT. Here the
GPT is generated from the 4.2 template (`EFI_0.img`, 11 sectors per LUN) instead. On my unit only two LUNs change:

- **LUN0:** partitions after `erecovery_ramdisk` move. `super` 1 927 168 → 1 878 016 sectors, `version`
  8 192 → 147 456, `preas` 262 144 → 75 776, and **`userdata` moves from LBA 2 829 824 to 2 733 568**. That move
  is why all data is lost.
- **LUN4:** `secdata` shrinks to 7 sectors and a new `dfx` partition is added. On my unit everything in `secdata`
  after its first 7 sectors was zero, so nothing was lost. **Check yours** (the `secdata` file in your backup)
  before going on.
- LUN 1, 2, 3 and 5 do not change.

### How `gptmake.py` works

- It takes the 4.2 template entries for one LUN.
- It keeps your device's disk GUID and the unique GUIDs of partitions with the same name, including the
  `last_parti` sentinel entry. New partitions get random GUIDs.
- It grows the last partition to the device's last usable LBA. That is Huawei's own rule: with it, the script
  reproduces the unchanged LUN 1/2/3/5 GPTs of my device **byte for byte**, CRCs included.
- It checks bounds and overlaps and writes three files: `_primary.bin` (LBA 0–5), `_bakent.bin` (backup entries,
  4 sectors) and `_bakhdr.bin` (backup header, 1 sector).

### Steps

1. **Self-test first.** Run it on the LUNs that should not change. All four must print `SAME`:

```
python scripts\gptmake.py C:\mp11\img\base\EFI_0.img 1 C:\mp11\backup\lun1\gpt_main1.bin x --selftest
python scripts\gptmake.py C:\mp11\img\base\EFI_0.img 2 C:\mp11\backup\lun2\gpt_main2.bin x --selftest
python scripts\gptmake.py C:\mp11\img\base\EFI_0.img 3 C:\mp11\backup\lun3\gpt_main3.bin x --selftest
python scripts\gptmake.py C:\mp11\img\base\EFI_0.img 5 C:\mp11\backup\lun5\gpt_main5.bin x --selftest
```

   (The folder names under `backup` depend on the edl version; use wherever `gpt_mainN.bin` was saved.)
   If any of them says `DIFFERENT`, **stop**: your device differs from mine and the generated GPT can't be trusted.

2. **Find where your backup GPT entries are.** On LUN0 of my unit the backup entries are **not** at
   "backup header − 4"; they start right after the last usable LBA. Read your own backup header:

```
python scripts\gptinfo.py C:\mp11\backup\lun0\gpt_main0.bin
```

   Note "other header LBA" (= backup header, `B0`). Then, in EDL, read that one sector:

```
edl rs <B0> 1 C:\mp11\gpt\bakhdr0_orig.bin --lun=0
python scripts\gptinfo.py C:\mp11\gpt\bakhdr0_orig.bin
```

   "entries at LBA" is your backup-entries LBA (`E0`). On my unit: `B0` = 30 693 375, `E0` = 30 692 864.
   Do the same for LUN4 (`B4`, `E4`; on mine 524 287 and 524 283).

3. Generate LUN0 and LUN4:

```
mkdir C:\mp11\gpt
python scripts\gptmake.py C:\mp11\img\base\EFI_0.img 0 C:\mp11\backup\lun0\gpt_main0.bin C:\mp11\gpt\lun0 --backup-entries-lba=<E0>
python scripts\gptmake.py C:\mp11\img\base\EFI_0.img 4 C:\mp11\backup\lun4\gpt_main4.bin C:\mp11\gpt\lun4 --backup-entries-lba=<E4>
```

4. Look at the result and note the new start of `metadata` and `userdata`:

```
python scripts\gptinfo.py C:\mp11\gpt\lun0_primary.bin
```

   Mine: `metadata` first 255 488 (4 096 sectors), `userdata` first 2 733 568.

5. **Check that every image fits** and generate the flash script. Copy the unchanged `gpt_main1/2/3/5.bin`
   next to the new `lun0_primary.bin` / `lun4_primary.bin` first:

```
copy C:\mp11\backup\lun1\gpt_main1.bin C:\mp11\gpt\
copy C:\mp11\backup\lun2\gpt_main2.bin C:\mp11\gpt\
copy C:\mp11\backup\lun3\gpt_main3.bin C:\mp11\gpt\
copy C:\mp11\backup\lun5\gpt_main5.bin C:\mp11\gpt\
python scripts\flashplan.py C:\mp11\img C:\mp11\gpt C:\mp11\flash42.ps1
```

   It prints a table of image → partition with sizes and must end without any `PROBLEM` line (44 writes on my
   unit). Run it once with your **old** GPT folder as a sanity check: it should report exactly the three
   overflows from the table above.

## 6. Build the new oeminfo

The region and model live in oeminfo. The Global unit says `hw/eu` and `DBY-W09S`; the China firmware expects
`all/cn` and `DBY-W09`. `oeminfo_region.py` changes exactly those two records (9 bytes on my unit) and leaves
everything else alone.

Use a **fresh** oeminfo dump, read right before writing, not an old backup: some runtime records change (mine
differed from the morning backup in 128 bytes). In EDL:

```
edl r oeminfo C:\mp11\oeminfo_now.bin
python scripts\oeminfo_region.py C:\mp11\oeminfo_now.bin C:\mp11\oeminfo_cn.bin
```

It lists the old values and must print `changed bytes: 9` (or a similar small number). Anything large means
something is wrong.

## 7. Write GPT and oeminfo in EDL

Do this in one EDL boot, in this order, and check each read-back before going on. `<B0>`, `<E0>`, `<B4>`, `<E4>`
are your values from step 5.

```
adb reboot edl

:: a. save the current GPT sectors (for going back)
edl rs 0 6 C:\mp11\gpt\orig_lun0_primary.bin --lun=0
edl rs <E0> 4 C:\mp11\gpt\orig_lun0_bakent.bin --lun=0
edl rs <B0> 1 C:\mp11\gpt\orig_lun0_bakhdr.bin --lun=0
edl rs 0 6 C:\mp11\gpt\orig_lun4_primary.bin --lun=4
edl rs <E4> 4 C:\mp11\gpt\orig_lun4_bakent.bin --lun=4
edl rs <B4> 1 C:\mp11\gpt\orig_lun4_bakhdr.bin --lun=4

:: b. oeminfo, then read it back and compare hashes
edl w oeminfo C:\mp11\oeminfo_cn.bin
edl r oeminfo C:\mp11\check_oeminfo.bin

:: c. GPT, then read back and compare hashes
edl ws 0     C:\mp11\gpt\lun0_primary.bin --lun=0
edl ws <E0>  C:\mp11\gpt\lun0_bakent.bin  --lun=0
edl ws <B0>  C:\mp11\gpt\lun0_bakhdr.bin  --lun=0
edl ws 0     C:\mp11\gpt\lun4_primary.bin --lun=4
edl ws <E4>  C:\mp11\gpt\lun4_bakent.bin  --lun=4
edl ws <B4>  C:\mp11\gpt\lun4_bakhdr.bin  --lun=4
edl rs 0 6 C:\mp11\gpt\check_lun0.bin --lun=0
edl rs 0 6 C:\mp11\gpt\check_lun4.bin --lun=4
edl printgpt --lun=0
edl printgpt --lun=4

:: d. wipe the start of metadata and userdata at their NEW locations
edl es <metadata first> 4096 --lun=0
edl es <userdata first> 16384 --lun=0

:: e. reboot into fastboot: hold Volume Down
edl reset
```

Compare `certutil -hashfile` of each `check_*` file with the file you wrote (`check_oeminfo.bin` vs
`oeminfo_cn.bin`, `check_lun0.bin` vs `lun0_primary.bin`, and so on). If a hash differs, write it again and do
not leave EDL until they match.

Step d makes Android treat metadata and userdata as empty. On my unit `es <metadata first> 4096` and
`es 2733568 16384` (the first 64 MiB of userdata) were enough. The firehose stopped answering after the userdata
erase: see [Troubleshooting](#troubleshooting).

## 8. Flash HarmonyOS 4.2 in fastboot

You must be in **bootloader fastboot**, not fastbootd:

```
fastboot getvar is-userspace     -> is-userspace: no
fastboot getvar unlocked         -> unlocked: yes
```

Then run the generated script in PowerShell:

```
powershell -ExecutionPolicy Bypass -File C:\mp11\flash42.ps1
```

The script checks `is-userspace: no` before **every** write, stops at the first error and never writes ABL. It
skips ABL, the GPT template (EFI/FI), the package tables (PTABLE_*), CRC, signature and version records.

Big sparse images (`super`, `preload`) "finish" in milliseconds. That is normal: this ABL reports
`parallel-download-flash: yes` and writes in the background. I read back samples of `super` in EDL afterwards and
they matched the image.

When it ends: `fastboot getvar unlocked` (still `yes`) → `fastboot reboot`.

## 9. First boot

On my unit the first boot looped, and the last kernel log said `/data mount fail`: Huawei's init does not
format a wiped userdata by itself. Fix:

1. Get to fastboot (Volume Down while it restarts) → `fastboot reboot recovery`.
2. In recovery choose **Wipe data / factory reset** and confirm.
3. It boots into the Chinese setup screen. Select your language in the first screen; the rest is in that language.

Check in Settings → About: `4.2.0.208(C00E100)`. `fastboot oem lock-state info` should still say unlocked.

## 10. Root with APatch

1. Enable Developer options and USB debugging again.
2. Install the APatch APK (`adb install APatch_....apk`).
3. Copy the 4.2 boot image you extracted: `adb push C:\mp11\img\base\BOOT_0.img /sdcard/Download/`
4. APatch → **Patch** → select `BOOT_0.img` → set a **SuperKey** (remember it) → start. The output lands in
   `/sdcard/Download/apatch_patched_*.img`.
5. Flash it:

```
adb pull /sdcard/Download/apatch_patched_XXXX.img C:\mp11\boot_patched.img
adb reboot bootloader
fastboot flash boot C:\mp11\boot_patched.img
fastboot reboot
```

6. Open APatch, enter the SuperKey, and install AndroidPatch (`apd`) when it offers.
7. Modules → install `magic_mount_rs-4.0.12-941-arm64.zip` → **reboot**. APatch needs this metamodule before it
   mounts any other module.

faxcon's Drive folder also has a pre-patched `bootHMOS4.2.img`. I patched the boot from the official package
myself instead, so I know what's in it.

## 11. Google Play services

### 11.1 Build and install the module

The module is a minimal subset of MindTheGapps 12.1 arm64: GmsCore, Google Services Framework, Play Store
(Phonesky), GooglePartnerSetup, the contacts/calendar sync adapters, and the privapp-permission and sysconfig XMLs
they need. No setup wizard, no Velvet, no extra apps. The files are copied byte for byte from the official zip.

```
python scripts\build_gms_module.py MindTheGapps-12.1.0-arm64-20231025_200924.zip gms12_systemless.zip
adb push gms12_systemless.zip /data/local/tmp/
adb shell su -c "/data/adb/apd module install /data/local/tmp/gms12_systemless.zip"
adb reboot
```

(Or install the zip from APatch → Modules.)

Why these paths: on HOS 4.2 `/product` and `/system_ext` are symlinks into `/system`, so the module must use
`system/product/...` and `system/system_ext/...`. `ro.control_privapp_permissions=enforce` is set, so the
permission XMLs have to be complete; Android refuses to start system_server when a priv-app permission is missing from them.

Check after reboot:

```
adb shell pm list packages -s | findstr google
adb shell dumpsys package com.google.android.gms | findstr "versionName privapp"
```

### 11.2 Register the device

An uncertified device has to be registered before Google sign-in works reliably.

1. Open Play Store once and wait a minute so GSF creates its ID.
2. Read the GSF ID:

```
adb shell su -c "cp /data/data/com.google.android.gsf/databases/gservices.db /sdcard/Download/"
adb pull /sdcard/Download/gservices.db
python -c "import sqlite3;print(sqlite3.connect('gservices.db').execute(\"select value from main where name='android_id'\").fetchone()[0])"
adb shell rm /sdcard/Download/gservices.db
```

3. Enter that number at Google's official page <https://www.google.com/android/uncertified> while signed in with
   the account you'll use on the tablet.
4. Wait (minutes to an hour), then add the account in Settings → Accounts. Play Store updates GMS by itself.

### 11.3 Runtime permissions

Without these, contacts and calendar don't sync:

```
adb push scripts\grant-runtime-permissions.sh /data/local/tmp/
adb shell su -c "sh /data/local/tmp/grant-runtime-permissions.sh"
```

### 11.4 Checkin fails: "unknown" is not a valid IMEI

**Symptom.** About a day after setup, Google apps show "This device isn't Play Protect certified". In logcat every
checkin fails:

```
W/Checkin: [CheckinRequestProcessor] Default Task : Checkin failed: https://android.googleapis.com/checkin
           (fragment #0) invalid hardware identifier: "unknown" is not a valid IMEI (expect 15 decimal digits)
```

Trigger a checkin by hand and watch for that line:

```
adb shell su -c "am broadcast -a android.provider.Telephony.SECRET_CODE -d android_secret_code://2432546 -p com.google.android.gms"
adb logcat -s Checkin
```

**Cause.** On HarmonyOS, `TelephonyManager.getImei()` (no argument) does not take the AOSP path. It calls
`HwInnerTelephonyManager.getUniqueDeviceId()`, and on this Wi-Fi-only tablet that returns the literal string
`"unknown"`. AOSP returns `null` when there is no modem, and `getImei(0)` really does return `null` here.
Play services 21.48 (the version in the module) accepted the value. 26.41 checks it and the checkin is rejected.
The last checkin that worked on my unit was one minute before Play Store updated Play services. The app block
appeared about 25 hours later; this timing alone does not establish why Google rejected the old identity.

**Fix.** [`imeifix/`](imeifix) is a small Xposed module. Its scope is Play services only. When
`TelephonyManager.getImei()`, `getDeviceId()` or `getMeid()` return `"unknown"`, the module returns `null`
instead, which is the AOSP behaviour. It returns no made-up identifier and changes nothing else. It needs a Zygisk
implementation and an Xposed framework on APatch. I used:

| What | Where |
|---|---|
| NeoZygisk v2.4 (`NeoZygisk-v2.4-289-release.zip`) | <https://github.com/JingMatrix/NeoZygisk/releases> |
| Vector v2.2 (LSPosed fork, `Vector-v2.2-3080-Release.zip`) | <https://github.com/JingMatrix/LSPosed/releases> |

```
adb push NeoZygisk-v2.4-289-release.zip /data/local/tmp/nz.zip
adb push Vector-v2.2-3080-Release.zip /data/local/tmp/vector.zip
adb shell su -c "/data/adb/apd module install /data/local/tmp/nz.zip"
adb shell su -c "/data/adb/apd module install /data/local/tmp/vector.zip"
adb reboot

cd imeifix && sh build.sh                 (needs the Android SDK build-tools 36 and JDK 17)
adb install imeifix.apk
adb shell su -c "/data/adb/lspd/cli modules enable local.dbyw09.imeifix"
adb shell su -c "/data/adb/lspd/cli scope set local.dbyw09.imeifix com.google.android.gms/0"
adb shell su -c "am force-stop com.google.android.gms"
```

Then trigger a checkin as above. It should log `Checkin Succeeded`. Initially it did, but **the apps stayed
blocked**: after the successful checkin, Google's server returned an "uncertified" verdict (GSF
`uncertified_status` went from `1` with a 25-hour expiry to `3` with no expiry). Clearing the cached verdict
(`files/gmscompliance/shared/cache.pb` in Play services' data folder) only fetched the same verdict again.
Registering the GSF ID again is not possible: the page says it is already registered.

### 11.5 Recovery with a new, officially registered GSF identity

Later on 26 Oct, backing up and resetting only the linked GSF/GMS Checkin identity state let Google's Checkin
allocate a new GSF ID. The owner registered it at <https://www.google.com/android/uncertified/>. Another successful
Checkin was followed by working Google apps. The old identity, token files and preferences remain in a private
rollback checkpoint. No Google APK, device fingerprint or hardware attestation was changed.

Read the [full recovery and prevention report](reports/2026-10-26-gsf-recovery.md) before attempting anything
similar. A GSF-only reset can leave GMS using the old identity/token; a blind `pm clear` can remove more state
than needed. This is a one-device result, and the exact reason the old identity was rejected is unresolved.

**Follow-up, 28 Oct:** This was temporary. The same new ID is blocked again despite successful Checkin. Do not
treat repeated identity resets as a durable fix. The [follow-up report](reports/2026-10-28-recurrence.md) records
the failed post-25-hour test and the reversible experiments used to distinguish caching from access denial.

Keep NeoZygisk, Vector and the IMEI fix active. The [optional Checkin guard](checkin-guard/) provides an hourly
health log and an 18-hour stale-Checkin fallback. It does not override a server denial or guarantee future access.

## 12. After setup

- **Chinese keyboard:** install Gboard from Play Store and set it as the default input method.
- **Chinese apps:** remove them with `adb shell pm uninstall -k --user 0 <package>` only. That removes them for
  the user and nothing is deleted from the system partition, so `adb shell cmd package install-existing <package>`
  brings any of them back. Keep `com.huawei.android.thememanager` if you want themes.
- **Time zone:** it starts on Asia/Shanghai. Settings → System → Date & time: turn off automatic time zone and
  pick yours.
- **AdAway:** `/system` is read-only (erofs), so AdAway's root mode needs a systemless hosts module (a module with
  `system/etc/hosts`).
- **Apps using MicroG (ReVanced-type):** Huawei's launch manager stops other apps from starting MicroG. Settings →
  Battery → App launch → MicroG → Manage manually, and enable all three switches.
- **Never accept OTA or HiSuite updates.** They rewrite bootloader components, may bring back the stock ABL, and
  4.2 offers no software way into EDL if the bootloader is locked.

## Troubleshooting

| Symptom | What helped |
|---|---|
| Firehose stops answering (after an erase, or a long pause) | Hold Power + Volume Up + Volume Down until it restarts, then Volume Down for fastboot, or `adb reboot edl` again. |
| `adb reboot edl` just reboots normally | You're on HOS 3.x Global. Go back to HOS 2 first (step 1). On 4.2 with an unlocked bootloader use `fastboot oem edl`. |
| EDL device shows with a yellow mark / edl can't open it | Install WinUSB with Zadig on QUSB_BULK_CID:0412. |
| `adb` says "unauthorized" or device not found | Close HiSuite and kill `hwtransport.exe`. |
| PowerShell 5.1 treats fastboot output as an error | fastboot writes progress to stderr. The generated script handles this; don't change `$ErrorActionPreference` to `Stop`. |
| Bootloop with `/data mount fail` after flashing | Step 9: `fastboot reboot recovery` → factory reset. |
| Git Bash turns `/sdcard/...` into `C:/Program Files/Git/sdcard/...` | Use cmd/PowerShell, or `MSYS_NO_PATHCONV=1` in Git Bash. |
| Contacts / calendar don't sync | Run the permission script (11.3). |
| Play Store says "device not certified" | Expected. Registration (11.2) is what makes sign-in work; certification stays off. |
| Google apps open only "This device isn't Play Protect certified" | Check whether checkin fails with `"unknown" is not a valid IMEI` and install the fix (11.4). If checkin succeeds and the block stays, see the status update at the top: I have no fix for that part. |

## Going back

- **Remove only GMS (keep root):** first uninstall the updates of Play Store and Play services in Settings → Apps,
  then APatch → Modules → remove the module → reboot.
- **Remove the IMEI fix:** `adb uninstall local.dbyw09.imeifix`, then APatch → Modules → remove Vector and
  NeoZygisk → reboot.
- **Remove root:** `fastboot flash boot C:\mp11\img\base\BOOT_0.img` (the unpatched 4.2 boot).
- **Back to HOS 2 Global (all from your backup, in EDL):** write the saved original GPT sectors back to the same
  LBAs (`orig_*.bin` from step 7a), write the original oeminfo, then restore the LUN0/LUN4 partitions from the
  backup (`edl wl C:\mp11\backup\lun0 --lun=0 --skip=userdata` etc. — check the edl help for your version).
  You end up on your HOS 2.0.0.278 with the data wiped.
- **Re-locking the bootloader:** only with the stock boot **and** the stock ABL back in place. Never lock with a
  patched boot.

## Scripts in this repository

The scripts in `scripts/` only read their inputs and write new files; none of them talks to the device.

| Script | What it does |
|---|---|
| [`scripts/updateapp.py`](scripts/updateapp.py) | Lists or extracts the images in a Huawei `UPDATE.APP`. |
| [`scripts/gptinfo.py`](scripts/gptinfo.py) | Prints a GPT header and partition list from a dump (4096-byte sectors). |
| [`scripts/gptmake.py`](scripts/gptmake.py) | Builds a device-specific GPT for one LUN from the 4.2 template; `--selftest` compares against an unchanged LUN. |
| [`scripts/oeminfo_region.py`](scripts/oeminfo_region.py) | Changes the oeminfo region/model records to `all/cn` / `DBY-W09`. |
| [`scripts/flashplan.py`](scripts/flashplan.py) | Maps images to partitions of the new GPT, checks sizes, writes the PowerShell flash script. |
| [`scripts/build_gms_module.py`](scripts/build_gms_module.py) | Builds the systemless GMS module from the official MindTheGapps 12.1 zip (checks its hash). |
| [`scripts/grant-runtime-permissions.sh`](scripts/grant-runtime-permissions.sh) | Grants the runtime permissions the Google sync adapters need. |
| [`imeifix/`](imeifix) | Xposed module (source + `build.sh`): returns `null` instead of HarmonyOS's `"unknown"` IMEI in Play services, see 11.4. Runs on the device. |
| [`checkin-guard/`](checkin-guard/) | Optional APatch module: logs Checkin health hourly; requests normal Checkin after 18 hours without success. No identity resets or attestation changes. |

This repository contains **no** firmware, loaders, ABL images, Google APKs or device backups. Get them from the
sources above.

## Credits

- **faxcon** for the XDA guide this is based on, and the links to the signed firehose and unlock ABL.
- **scoolo** (4PDA) for finding the method; **kylandomos** for showing that 4.2 can be reached with the unlock kept.
- [bkerler/edl](https://github.com/bkerler/edl), [APatch](https://github.com/bmax121/APatch),
  [meta-magic_mount-rs](https://github.com/Tools-cx-app/meta-magic_mount-rs),
  [MindTheGapps](https://github.com/MindTheGapps).

Huawei, HarmonyOS, Google, Android and Netflix are trademarks of their owners. This project is not affiliated with
any of them.

## License

The scripts are under the [MIT License](LICENSE). No warranty: if your tablet bricks, it's on you.
