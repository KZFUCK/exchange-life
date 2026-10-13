#!/usr/bin/env python3
"""Build an offline Mac playtest with only active BD source and official runtime."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,zipfile
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--edition',choices=['channels','full-flow'],default='full-flow')
args=parser.parse_args()
full=args.edition=='full-flow'
out=root/'builds'/('market-maker-bd-full-flow-20261013' if full else 'market-maker-bd-channels-20261013')
archive=root/'builds'/('做市商BD研修_完整流程_Mac_20261013.zip' if full else '做市商BD研修_四渠道_Mac_20261013.zip')
if out.exists() or archive.exists():raise SystemExit('Output already exists; retain it and choose a new version directory.')
game=out/'game';game.mkdir(parents=True)
source=root/'bnb'
files=['project.godot','mm_icon.svg','scenes/mm_bd.tscn']
files += [str(p.relative_to(source)) for pattern in ['scripts/mm_bd*.gd*','data/mm_bd*.json','assets/mm_anime/*.png','assets/mm_anime/*.png.import'] for p in source.glob(pattern)]
for relative in files:
 p=game/relative;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source/relative,p)
project=game/'project.godot';text=project.read_text();text=text.replace('[autoload]\n\n_mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"\n\n','').replace('[editor_plugins]\n\nenabled=PackedStringArray("res://addons/godot_ai/plugin.cfg")\n\n','');project.write_text(text)
shutil.copy2(root/'builds/market-maker-bd-20261013/game/export_presets.cfg',game/'export_presets.cfg')
engine=root/'downloads/Godot.app';runtime=engine/'Contents/MacOS/Godot'
with (out/'build.log').open('w') as log:
 subprocess.run([str(runtime),'--headless','--path',str(game),'--editor','--import','--quit'],stdout=log,stderr=subprocess.STDOUT,check=True)
 subprocess.run([str(runtime),'--headless','--path',str(game),'--export-pack','BD Training Pack',str(out/'training.pck')],stdout=log,stderr=subprocess.STDOUT,check=True)
log=(out/'build.log').read_text()
if any(x in log for x in ['SCRIPT ERROR','Parse Error','ERROR:']):raise SystemExit('Inspect build.log before packaging; Godot logged errors.')
shutil.copytree(engine,out/'engine/Godot.app',copy_function=os.link)
prior=root/'builds/market-maker-bd-20261013'
for name in ['开始研修.command','兼容模式.command','Godot_LICENSE.txt']:shutil.copy2(prior/name,out/name)
(out/'使用说明.md').write_text('''# 做市商 BD 研修 · 客户业务培训\n\n双击“开始研修.command”；兼容模式可用于图形兼容性问题。内置官方 Godot 运行时，无需安装 Godot；这是本地 Mac 试玩包，尚非签名发行安装包。\n\n“渠道课程”包括机制、计算实验与情景题；“客户委托”包括 Uniswap、Alpha、合约三份完整委托，均有六项访谈、渠道报价、三轮谈判、六日交付和复盘。原有三个现货 BD 委托保留。新委托操作自动保存，顶部按钮按当前页面保存/读取会谈或新委托；机制测验使用另一份独立自动存档。\n\n全部金额、费率和 MMR 为教学示例。Alpha 授权执行、集中流动性头寸和 USDT 线性永续教学账各有简化边界，课程内明确说明；不接入钱包、API 或真实交易。参考规则核对于 2026-10-13，实际业务前按最新官方规则与公司 SOP 确认。\n''')
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest=dict(target='macOS local offline playtest',version='full-client-flow-20261013' if full else 'four-channel-20261013',pck_sha256=digest(out/'training.pck'),runtime_sha256=digest(runtime),runtime_unmodified=True,development_plugin_removed=True,source_sha256={r:digest(source/r) for r in files},case_data_unchanged=True)
(out/'package_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in out.rglob('*'):
  if p.is_file() and p.relative_to(out).parts[0] not in ['game','build.log']:z.write(p,str(Path(out.name)/p.relative_to(out)))
with zipfile.ZipFile(archive) as z:
 if z.testzip():raise SystemExit('ZIP CRC failed')
 entries=z.namelist()
 assert not any('/game/' in n or '/qa/' in n for n in entries)
 assert z.getinfo(out.name+'/开始研修.command').external_attr>>16&0o111
print(json.dumps(dict(package=str(out),zip=str(archive),pck_sha256=manifest['pck_sha256'],zip_sha256=digest(archive)),ensure_ascii=False))
