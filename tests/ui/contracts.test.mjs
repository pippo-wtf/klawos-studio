import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {test} from 'node:test';
import {resolve} from 'node:path';

test('Python snapshot reaches JavaScript with an exact string UID', () => {
  const result = spawnSync(resolve('runtime/python/bin/python3.12'), ['-c',
    "from pathlib import Path; import json; from klawos_device.model import parse_snapshot; print(json.dumps(parse_snapshot(Path('tests/fixtures/baseline.vil').read_bytes()).to_wire()))"],
    {encoding: 'utf8', env: {...process.env, PYTHONPATH: resolve('service')}});
  assert.equal(result.status, 0, result.stderr);
  const wire = JSON.parse(result.stdout);
  assert.equal(wire.identity.uid, '6994672159869375106');
  assert.equal(wire.hardware.uid, '6994672159869375106');
  assert.equal(typeof wire.identity.uid, 'string');
  assert.equal(wire.hardware.layout.length, 6);
});
