# SPDX-License-Identifier: GPL-2.0-or-later
# Static setting codecs adapted from Vial v0.7.5 editor/qmk_settings.py.
import json
from pathlib import Path
from collections import defaultdict
class QmkSettings:
    settings_defs=json.loads(Path(__file__).with_name('qmk_settings.json').read_text())
    qsid_fields=defaultdict(list)
    for tab in settings_defs['tabs']:
        for field in tab['fields']: qsid_fields[field['qsid']].append(field)
    @classmethod
    def is_qsid_supported(cls,qsid): return qsid in cls.qsid_fields
    @classmethod
    def qsid_deserialize(cls,qsid,data):
        fields=cls.qsid_fields[qsid]; field=fields[0]
        if field['type']=='integer' and len(fields)!=1: raise ValueError('Conflicting setting definitions')
        if field['type'] not in ('boolean','integer'): raise ValueError('Unsupported field')
        width=field.get('width',1)
        if len(data)<width: raise ValueError('Short setting value')
        return int.from_bytes(data[:width],'little')
    @classmethod
    def qsid_serialize(cls,qsid,data):
        if type(data) is not int: raise ValueError('Expected integer setting')
        return data.to_bytes(cls.qsid_fields[qsid][0].get('width',1),'little')
