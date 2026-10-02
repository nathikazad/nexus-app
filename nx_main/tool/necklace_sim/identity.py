"""Software device identity implementing NecklaceIdentity's BLE exchange seam.

Private state is separate from test artifacts, mode 0600. No bearer bypass:
NecklaceDeviceAuth performs the normal server challenge/token exchange.
"""
import json
import os
from pathlib import Path
import sys
import uuid
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils


class Identity:
    def __init__(self, path):
        self.path = Path(path)
        self.state = json.loads(self.path.read_text()) if self.path.exists() else None
        if self.path.exists() and self.path.stat().st_mode & 0o077:
            raise PermissionError('Identity state must have permissions 0600')

    def save(self):
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        temporary = self.path.with_suffix('.pending')
        with open(os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), 'w') as f:
            json.dump(self.state, f)
            f.flush()
            os.fsync(f.fileno())
        os.replace(temporary, self.path)

    def exchange(self, data):
        if not data:
            raise ValueError('Empty identity request')
        op = data[0]
        if op == 2 and len(data) != 49:
            raise ValueError('Invalid provisioning request')
        if op == 2 and len(data) == 49:
            identifier = str(uuid.UUID(bytes=data[1:17]))
            if self.state and (self.state['id'] != identifier or not self.state.get('secret')):
                raise ValueError('Identity already provisioned')
            key = ec.generate_private_key(ec.SECP256R1()) if not self.state else self.key()
            self.state = {'id': identifier, 'secret': data[17:].hex(),
                          'key': key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                                   serialization.NoEncryption()).decode()}
            self.save()
        if self.state is None:
            if op == 1 and len(data) == 1:
                return bytes(82)
            raise ValueError('Device not provisioned')
        key = self.key()
        public = key.public_key().public_bytes(serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
        if op in (1, 2):
            if op == 1 and len(data) != 1:
                raise ValueError('Invalid inspect request')
            return uuid.UUID(self.state['id']).bytes + public + bytes([bool(self.state.get('secret'))])
        if op == 3 and len(data) == 33:
            message = f"NexusDevice/v1\n{self.state['id']}\n{data[1:].hex()}".encode()
            signature = key.sign(message, ec.ECDSA(hashes.SHA256()))
            r, s = utils.decode_dss_signature(signature)
            secret = bytes.fromhex(self.state.get('secret', ''))
            return public + r.to_bytes(32, 'big') + s.to_bytes(32, 'big') + bytes([bool(secret)]) + secret
        if op == 4 and len(data) == 1:
            self.state.pop('secret', None)
            self.save()
            return b''
        raise ValueError('Unsupported identity request')

    def key(self):
        return serialization.load_pem_private_key(self.state['key'].encode(), password=None)


if __name__ == '__main__':
    identity = Identity(sys.argv[1])
    for line in sys.stdin:
        try:
            result = identity.exchange(bytes.fromhex(json.loads(line)['hex']))
            print(json.dumps({'hex': result.hex()}), flush=True)
        except Exception as error:
            # Never log request/proof/key/token contents.
            print(json.dumps({'error': type(error).__name__}), flush=True)
