// Execute the production handlers with desktop delivery replaced by a recorder.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(process.argv[2], 'utf8');
const handlers = source.slice(source.indexOf('  function open('), source.indexOf('  PanelWindow {'));
const commands = [];
const root = { opened: false, addressPattern: /^0x[0-9A-Fa-f]+$/, shell: { hide() {} }, manifest: null };
const context = vm.createContext({ root, confirmDialog: {}, keyCatcher: {},
  Qt: { callLater() {} }, Quickshell: { env() { return '/home/a user'; }, execDetached(argv) { commands.push(Array.from(argv)); } } });
vm.runInContext(handlers, context);
for (const name of ['open', 'close', 'dismiss', 'toggle', 'doClose']) root[name] = context[name];
const original = { address: '0xabc', title: 'one', pid: 123, started: '9007199254740993' };
const open = data => root.open(JSON.stringify(data));
for (const data of [null, [], {}, {...original, pid: [123]}, {...original, pid: [[123]]}, {...original, pid: {}}, {...original, address: '0x1;evil'}, {...original, pid: 0},
                    {...original, started: 123}, {...original, started: '1;evil'}]) {
  open(data); root.doClose(); assert.equal(root.opened, false); assert.equal(commands.length, 0);
}
open(original);
assert.equal(context.confirmDialog.selectedIndex, 1);
open({...original, address: '0xdef', pid: 456});
assert.equal(root.targetAddress, '0xabc');
root.doClose(); root.doClose();
assert.equal(commands.length, 1);
assert.deepEqual(commands[0], ['/home/a user/.config/omarchy/plugins/flaviozantut.close-confirm/bin/omarchy-close-confirm',
  '--close', '0xabc', '123', '9007199254740993']);
assert.equal(root.opened, false);
for (const cancel of ['close', 'dismiss', 'toggle']) {
  open(original); root[cancel](); root.doClose();
  assert.equal(root.opened, false); assert.equal(root.targetAddress, ''); assert.equal(root.targetPid, '');
  assert.equal(root.targetStarted, ''); assert.equal(commands.length, 1);
}
console.log('ok - production handlers reject malformed requests, retain pending target, consume once, and cancel cleanly');
