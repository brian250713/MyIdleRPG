# Phase 5 長時平衡報告（Second Review）

`tools/balance_report.gd` 使用固定種子 `20260924`，與 fresh battlefield 的 RNG 初始化一致。

## 為何舊報告會漂移

上一版報告和實際戰場使用了不同的規則，差異不是單純亂數：

1. `recommended_level + 7` 在Lv.1開局就要求先在 1-1 刷到 Lv.8，實際一小時仍反覆 1-1。
2. 報告會自動裝備，而 fresh soak 的真實預設只自動開箱、不自動裝備。
3. 報告曾在「每個英雄」迴圈內呼叫寶箱掉落；實際 `Battlefield` 是每隻怪物只呼叫一次。三人隊時這會把藍箱／幕箱與金幣放大。
4. `BattleSim` 使用固定連續步長；`time_scale=8` 的實際 soak 會隨場景節點增加而降低每秒更新數，戰鬥時間因此被高估。

現在的修正如下：

- 進入門檻改為 `recommended_level + 1`。
- 報告和真實 soak 都使用 fresh-save 政策：自動開啟三種寶箱、英雄達 Lv.5/Lv.15 後填入牧師／遊俠、沒有自動裝備。裝備掉落與背包溢出仍照正式核心規則計算。
- `Chests`、`Rewards`、`XPCurve`、`Skills`、難度與靈魂石流程都直接呼叫正式 core module；每隻怪的寶箱掉落只執行一次。
- `core/live_pacing.gd` 提供從實際 soak 觀測到的 live frame profile：simulation step 約由 0.205 秒變成 0.370 秒，live contact delay 為 7.8 秒；報告把它傳給 `BattleSim` 的可設定參數。這是對應實際 fast-forward 更新頻率的模型，不是固定等待或額外遊戲時間。
- 報告的 gold calibration 使用同一個 live profile，避免把實際時間造成的 chest／overflow 差異誤判成新關卡 padding。

## 平衡表

Before 是上一版報告（`+7` 門檻、自動裝備、每英雄重複掉箱）；After 是目前規則。

| 里程碑 | Before 小時 | After 小時 | After 英雄等級 | After 金幣 | 卡住點 |
|---|---:|---:|---|---:|---:|
| 普通 1-10 | 1.970 | 1.080 | 騎士 11／牧師 10／遊俠— | 16,402 | 0 |
| 普通 2-10 | 3.541 | 4.855 | 騎士 21／牧師 20／遊俠 19 | 174,208 | 0 |
| 普通 3-10 | 5.977 | 9.182 | 騎士 31／牧師 30／遊俠 30 | 783,132 | 0 |
| 進入噩夢 1-1 | 6.308 | 9.835 | 騎士 32／牧師 31／遊俠 30 | 906,591 | 0 |

目前沒有超過 45 分鐘的失敗重試卡住點。普通 1-10 約 1.1 小時，普通 2-10 約 4.9 小時，普通 3-10 約 9.2 小時。

### 幕首領靈魂石

| 幕首領 | 付款時持有 | 付款前種石時間 |
|---|---:|---:|
| 普通 1-10 | 1 | 48.7 分鐘 |
| 普通 2-10 | 2 | 0 分鐘 |
| 普通 3-10 | 11 | 0 分鐘 |

藍箱／幕箱機率已由 10%／30% 調為 **2%／8%**。總靈魂石不再膨脹到數百顆；需要時會在上一關刷怪，但沒有形成超過一小時的硬阻塞。

## 10 分鐘與 60 分鐘交叉檢查

比較的是關卡、每一位英雄的等級與金幣；實際 soak 使用 `time_scale=8`，不是 1000 倍。數值誤差門檻為 20%，關卡是離散值，工具允許在關卡切換瞬間相鄰一關（本次兩次實際驗收的 `stage_delta` 都是 0）。

### 10 分鐘

| 來源 | 關卡 | 騎士 | 牧師 | 金幣 |
|---|---:|---:|---:|---:|
| `balance_report.gd` prediction | 4（普通 1-5） | 6 | 5 | 2,014 |
| 真實 soak | 4（普通 1-5） | 6 | 5 | 1,990 |

金幣誤差 1.2%，兩位英雄完全一致。

### 60 分鐘

| 來源 | 關卡 | 騎士 | 牧師 | 金幣 |
|---|---:|---:|---:|---:|
| `balance_report.gd` prediction | 8（普通 1-9） | 10 | 10 | 15,675 |
| 真實 soak | 8（普通 1-9） | 10 | 10 | 14,569 |

金幣誤差 7.1%，關卡與两位英雄完全一致。60 分鐘 real soak 已進入普通 1-9，達到「1-5 或更後段」的目標。

## Raw soak lines

### 10 game-minutes

```text
SOAK_CROSSCHECK simulated_minutes=10.10 stage=4 levels=knight6,priest5 gold=1990 predicted_stage=4 stage_delta=0 predicted_levels=knight6,priest5 predicted_gold=2014 lead_error_percent=0.0 max_level_error_percent=0.0 gold_error_percent=1.2 crosscheck_ok=true
SOAK_RESULT passed=true simulated_hours=0.17 real_seconds=75.75 time_scale=8.0 frames=3039 monster_kills=67 hero_deaths=0 stages_cleared=5 chests_dropped=8 white_chests=3 blue_chests=5 act_chests=0 items_gained=16 max_nodes=623 max_transient=12 max_inventory=16/40 max_chests=0/20 memory_start=93792190 memory_peak=129428382 memory_growth_mb=33 white_cooldown=53.4 effective_step=0.199
```

### 60 game-minutes

```text
SOAK_CROSSCHECK simulated_minutes=60.08 stage=8 levels=knight10,priest10 gold=14569 predicted_stage=8 stage_delta=0 predicted_levels=knight10,priest10 predicted_gold=15675 lead_error_percent=0.0 max_level_error_percent=0.0 gold_error_percent=7.1 crosscheck_ok=true
SOAK_RESULT passed=true simulated_hours=1.00 real_seconds=450.61 time_scale=8.0 frames=9911 monster_kills=269 hero_deaths=0 stages_cleared=20 chests_dropped=29 white_chests=9 blue_chests=20 act_chests=0 items_gained=55 max_nodes=834 max_transient=12 max_inventory=40/40 max_chests=0/20 memory_start=93792190 memory_peak=169080054 memory_growth_mb=71 white_cooldown=45.6 effective_step=0.364
```

重現 60 分鐘驗證：

```powershell
$env:SOAK_SIM_SECONDS='3600'
$env:CROSSCHECK_PREDICTED_STAGE='8'
$env:CROSSCHECK_PREDICTED_LEVELS='knight:10,priest:10'
$env:CROSSCHECK_PREDICTED_GOLD='15675'
$env:MYIDLE_TEST_MODE='1'
$env:MYIDLE_SAVE_PATH='user://soak_save.json'
<godot> --headless --path . --save-path=user://soak_save.json -s res://tools/soak_test.gd
```

所有報告時間都來自 `BattleSim` 結果、正式 2.2 秒通關／1.25 秒撤退轉場，以及 live frame profile；沒有 12 分鐘報告 padding。
