"""Software identity persistence and proof tests; no real credentials or network."""
import importlib.util
from pathlib import Path
import uuid
import pytest
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec, utils

spec = importlib.util.spec_from_file_location('sim_identity', Path(__file__).with_name('identity.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
Identity = module.Identity


def test_proof_persists_and_pairing_secret_is_cleared(tmp_path):
    path = tmp_path / 'identity.json'
    identity = Identity(path)
    identifier = uuid.uuid4()
    secret = bytes(range(32))
    assert identity.exchange(b'\x01') == bytes(82)
    before = identity.exchange(b'\x02' + identifier.bytes + secret)
    assert path.stat().st_mode & 0o077 == 0
    nonce = bytes(reversed(range(32)))
    proof = Identity(path).exchange(b'\x03' + nonce)
    public = ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), proof[:65])
    signature = utils.encode_dss_signature(int.from_bytes(proof[65:97], 'big'), int.from_bytes(proof[97:129], 'big'))
    message = f'NexusDevice/v1\n{identifier}\n{nonce.hex()}'.encode()
    public.verify(signature, message, ec.ECDSA(hashes.SHA256()))
    with pytest.raises(InvalidSignature):
        public.verify(signature, message + b'wrong-nonce', ec.ECDSA(hashes.SHA256()))
    assert proof[130:] == secret
    identity.exchange(b'\x04')
    after = Identity(path)
    assert after.exchange(b'\x01') == before[:81] + b'\x00'
    assert len(after.exchange(b'\x03' + nonce)) == 130
    with pytest.raises(ValueError):
        after.exchange(b'\x02' + uuid.uuid4().bytes + secret)


def test_invalid_provision_and_insecure_permissions_rejected(tmp_path):
    path = tmp_path / 'identity.json'
    identity = Identity(path)
    identity.exchange(b'\x02' + uuid.uuid4().bytes + bytes(32))
    with pytest.raises(ValueError):
        identity.exchange(b'\x02')
    path.chmod(0o644)
    with pytest.raises(PermissionError):
        Identity(path)
