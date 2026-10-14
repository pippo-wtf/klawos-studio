"""Lossless documents and validated process messages; no device or user-file access."""
from __future__ import annotations

import copy
import hashlib
import json
import re
from dataclasses import dataclass, field

MAX_BYTES = 4 * 1024 * 1024
MAX_DEPTH = 32
OPERATIONS = frozenset({'status', 'read', 'selectDevice', 'patch', 'discard', 'preview', 'apply',
                       'recover', 'import', 'export', 'feature', 'matrixStart', 'matrixStop',
                       'recordingStart', 'recordingStop', 'security', 'helperSettings',
                       'recheck', 'diagnostics', 'decode', 'validate', 'serialize', 'plan', 'verify'})


def _pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate JSON object key')
        result[key] = value
    return result


def _constant(value):
    raise ValueError('Non-finite JSON number')


def _depth(value, level=0):
    if isinstance(value, (dict, list)):
        level += 1
        if level > MAX_DEPTH:
            raise ValueError('JSON nesting exceeds 32 levels')
        for child in value.values() if isinstance(value, dict) else value:
            _depth(child, level)


def load_document(raw: bytes) -> dict:
    if not isinstance(raw, bytes) or len(raw) > MAX_BYTES:
        raise ValueError('Document exceeds the supported size')
    try:
        result = json.loads(raw, object_pairs_hook=_pairs, parse_constant=_constant)
        if not isinstance(result, dict):
            raise ValueError('Expected a JSON object')
        _depth(result)
        return result
    except (RecursionError, UnicodeError) as error:
        raise ValueError('Invalid JSON document') from error


@dataclass(frozen=True)
class DeviceIdentity:
    uid: str
    via_protocol: int
    vial_protocol: int
    definition_hash: str = ''

    def to_wire(self):
        return {'uid': self.uid, 'viaProtocol': self.via_protocol,
                'vialProtocol': self.vial_protocol, 'definitionHash': self.definition_hash}


def _safe_wire(value):
    # Unknown future fields can also contain integers beyond JavaScript precision.
    if type(value) is int and abs(value) > 9007199254740991:
        return {'$integer': str(value)}
    if isinstance(value, dict): return {k: _safe_wire(v) for k, v in value.items()}
    if isinstance(value, list): return [_safe_wire(v) for v in value]
    return value


@dataclass
class Snapshot:
    identity: DeviceIdentity
    hardware: dict
    lighting: dict = field(default_factory=dict)
    capabilities: dict = field(default_factory=dict)
    unreadable_fields: list[str] = field(default_factory=list)
    metadata: dict = field(default_factory=dict)
    captured_at: str = ''

    def to_vil(self) -> dict:
        result = copy.deepcopy(self.hardware)
        result['uid'] = int(self.identity.uid)
        return result

    def to_wire(self) -> dict:
        hardware = copy.deepcopy(self.hardware)
        hardware['uid'] = self.identity.uid
        return {'identity': self.identity.to_wire(), 'hardware': _safe_wire(hardware),
                'lighting': _safe_wire(self.lighting), 'capabilities': _safe_wire(self.capabilities),
                'unreadableFields': list(self.unreadable_fields), 'metadata': _safe_wire(self.metadata),
                'capturedAt': self.captured_at, 'revision': canonical_revision(self)}


def parse_snapshot(document: bytes) -> Snapshot:
    data = load_document(document)
    uid = data.get('uid')
    if isinstance(uid, str):
        if not re.fullmatch(r'[0-9]{1,20}', uid): raise ValueError('Invalid keyboard identifier')
        uid = int(uid)
    if type(uid) is not int or not 0 <= uid <= 18446744073709551615:
        raise ValueError('Invalid keyboard identifier')
    layout = data.get('layout')
    if not isinstance(layout, list) or not layout:
        raise ValueError('Missing keyboard layers')
    for layer in layout:
        if not isinstance(layer, list) or not layer:
            raise ValueError('Invalid keyboard matrix')
        for row in layer:
            if not isinstance(row, list): raise ValueError('Invalid keyboard row')
    identity = DeviceIdentity(str(uid), data.get('via_protocol', -1), data.get('vial_protocol', -1))
    return Snapshot(identity=identity, hardware=copy.deepcopy(data))


def canonical_revision(snapshot: Snapshot) -> str:
    persistent = {'identity': snapshot.identity.to_wire(), 'hardware': snapshot.to_vil(),
                  'lighting': snapshot.lighting, 'capabilities': snapshot.capabilities,
                  'unreadableFields': sorted(snapshot.unreadable_fields)}
    raw = json.dumps(persistent, sort_keys=True, separators=(',', ':'), ensure_ascii=True,
                     allow_nan=False).encode('utf-8')
    return hashlib.sha256(raw).hexdigest()


def resolve_binding(profiles: dict, context: str):
    overrides = profiles.get('overrides', {})
    return copy.deepcopy(overrides[context] if context in overrides else profiles.get('default', {'kind': 'none'}))


def validate_message(payload: bytes, *, known_revisions: set[str] | None = None) -> dict:
    message = load_document(payload)
    for key in ('requestID', 'operationID'):
        value = message.get(key)
        if not isinstance(value, str) or not value.strip() or len(value) > 128:
            raise ValueError('Missing process correlation')
    kind = message.get('kind')
    if kind not in {'command', 'exchange', 'exchangeResult', 'result', 'error'}:
        raise ValueError('Unsupported process message')
    if kind == 'command' and message.get('operation') not in OPERATIONS:
        raise ValueError('Unsupported operation')
    if not isinstance(message.get('payload'), dict): raise ValueError('Expected an object payload')
    if message.get('operation') in {'patch', 'discard', 'apply'}:
        revision = message.get('draftRevision')
        if not isinstance(revision, str) or not revision:
            raise ValueError('Reload the draft before saving')
        if known_revisions is not None and revision not in known_revisions:
            raise ValueError('The draft revision has expired')
    return message
