from pathlib import Path
from lupa import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
for path in (root / 'DensGuildMap').rglob('*.lua'):
    lua.execute('assert(load(...))', path.read_text(encoding='utf-8-sig'))
lua.execute('RAID_CLASS_COLORS = { WARRIOR = {}, MAGE = {} }')
addon = lua.table()
lua.execute((root / 'DensGuildMap/Protocol.lua').read_text(), 'DensGuildMap', addon)
data = addon.Decode('1;84;1234;9876;WARRIOR;60')
assert data.map == 84 and data.x == .1234 and data.y == .9876 and data.level == 60
for message in ['', '0', '2;84;0;0;MAGE;1', '1;0;0;0;MAGE;1',
                '1;84;10001;0;MAGE;1', '1;84;0;10001;MAGE;1',
                '1;84;0;0;FAKE;1', '1;84;0;0;MAGE;1001',
                '1;84;-1;0;MAGE;1', '1;84;nan;0;MAGE;1',
                '1;84;0;0;MAGE;1;extra', 'a' * 256]:
    assert addon.Decode(message) is None, message
assert addon.Decode('1;84;0;10000;MAGE;1') is not None
print('All Lua files compile; protocol bounds and malformed-message checks passed.')
