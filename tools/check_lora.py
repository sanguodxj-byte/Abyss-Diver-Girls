import json, struct
path = '/content/ComfyUI/models/loras/deepseekchan_moss.safetensors'
with open(path, 'rb') as f:
    header_len = struct.unpack('<Q', f.read(8))[0]
    meta = json.loads(f.read(header_len).decode('utf-8')).get('__metadata__', {})
    print("FULL_DESC:", meta.get('modelspec.description'))
    print("TRIGGER:", meta.get('modelspec.trigger_phrase'))
    print("TAGS:", meta.get('ss_tag_frequency'))
