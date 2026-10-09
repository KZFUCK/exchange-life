# 交易所人生 · Exchange Life

开发中的 Godot 3D 办公室经营游戏。管理员工、摆放工位、开发产品并扩大办公室。当前可玩原型包含四人、八人和十二人规模；完整玩法与最终画面仍待验收。

## 获取与运行

需要 Git、Git LFS 与 Godot 4.7.2。Mac 默认入口使用 Metal，另有 GL Compatibility 入口。

```sh
git lfs install
git clone https://github.com/KZFUCK/exchange-life.git
cd exchange-life
git lfs pull
```

在 Godot 中打开 `bnb/project.godot`，等待首次素材导入后按 F5。Mac 也可双击 `启动游戏.command` 或 `启动游戏_兼容模式.command`。脚本支持 `GODOT_BIN`，项目本地 Godot、`/Applications/Godot.app`、用户 Applications 目录和 PATH 中的 `godot`。

```sh
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot ./启动游戏.command
```

运行无需 Blender；编辑原生模型需要 Blender 4.5 LTS。

## 当前内容

- 常驻 3D 办公室：独立员工寻路、到岗打字、岗位桌面、共享区与原生窗光。
- 经营操作：招聘、配岗、买桌、摆放、移动、出售和办公室扩张。
- 项目循环：产品与目标用户选择、企划、开发、测试、上线评价与销售、研发点培养及解锁。
- 营业暂停与速度控制、周报、独立公司存档、有效备份与确认恢复。

代码在 `bnb/scripts/`，场景在 `bnb/scenes/`，运行规则在 `bnb/data/operations_v1.json`。当前 13 个 GLB 模型及其导入设置在 `bnb/assets/`；对应三个 Blender 源文件在 `art/blender/`，来源对应与 SHA-256 见 `bnb/assets/SOURCES.json`。

本公开仓库只包含当前游戏源码、必需插件、运行模型素材和对应原生源文件。历史制作记录、参考图、测试截图/日志、方案和数值工作簿、个人存档、安装包及引擎缓存未纳入。

## 验证

```sh
godot --headless --editor --path bnb --quit
godot --headless --path bnb --script tests/operations_runner.gd
godot --headless --path bnb --script tests/development_runner.gd
```

这些检查覆盖当前经营规则和存档契约，不表示玩法平衡、完整战役或画质已通过玩家验收。界面操作见 [bnb/README.md](bnb/README.md)，第三方许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
