#!/usr/bin/env python3
"""
IFinance — Relying Party de Passkeys (WebAuthn / FIDO2) — cap. 71.

Implementa o lado servidor do WebAuthn:
  • Registro  : gera PublicKeyCredentialCreationOptions, valida a atestação
                (clientDataJSON + authenticatorData) e guarda a CHAVE PÚBLICA.
  • Login     : gera PublicKeyCredentialRequestOptions e valida a assinatura
                (ES256 / RS256) feita pelo autenticador do dispositivo.
  • Digital Asset Links: gera `assetlinks.json` para Android.

A chave PRIVADA nunca chega aqui — só a pública. Toda a criptografia usa a
biblioteca `cryptography`; o CBOR usa `cbor2`.

Armazenamento: arquivo JSON (passkeys.json). Em produção, troque por um banco.
"""

from __future__ import annotations

import base64
import json
import os
import secrets
import threading
import time
from urllib.parse import urlparse

import cbor2
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa


# --------------------------------------------------------------------------- #
# Helpers base64url
# --------------------------------------------------------------------------- #
def b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def b64url_decode(s: str) -> bytes:
    if isinstance(s, str):
        s = s.encode("ascii")
    pad = b"=" * (-len(s) % 4)
    return base64.urlsafe_b64decode(s + pad)


# --------------------------------------------------------------------------- #
# Armazenamento
# --------------------------------------------------------------------------- #
class PasskeyStore:
    """Armazém simples (arquivo JSON) de usuários, credenciais e desafios."""

    def __init__(self, path: str):
        self.path = path
        self._lock = threading.Lock()
        self._data = {"users": {}, "challenges": {}}
        self._load()

    def _load(self):
        if os.path.isfile(self.path):
            try:
                with open(self.path, "r", encoding="utf-8") as fh:
                    self._data = json.load(fh)
            except Exception:
                self._data = {"users": {}, "challenges": {}}
        self._data.setdefault("users", {})
        self._data.setdefault("challenges", {})

    def _save(self):
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(self._data, fh, ensure_ascii=False, indent=2)
        os.replace(tmp, self.path)

    # --- usuários ---------------------------------------------------------- #
    def user(self, username: str):
        return self._data["users"].get(username.lower())

    def upsert_user(self, username: str, display_name: str):
        key = username.lower()
        user = self._data["users"].get(key)
        if user is None:
            user = {
                "username": username,
                "displayName": display_name or username,
                "userHandle": b64url_encode(secrets.token_bytes(16)),
                "credentials": [],
                "createdAt": int(time.time()),
            }
            self._data["users"][key] = user
        elif display_name:
            user["displayName"] = display_name
        return user

    def add_credential(self, username: str, credential: dict):
        user = self._data["users"][username.lower()]
        user["credentials"] = [
            c for c in user["credentials"] if c["id"] != credential["id"]
        ]
        user["credentials"].append(credential)

    def find_credential(self, credential_id: str):
        for username, user in self._data["users"].items():
            for cred in user["credentials"]:
                if cred["id"] == credential_id:
                    return username, user, cred
        return None, None, None

    # --- desafios ---------------------------------------------------------- #
    def put_challenge(self, kind: str, username: str, challenge: str, ttl=300):
        self._cleanup_challenges()
        cid = b64url_encode(secrets.token_bytes(24))
        self._data["challenges"][cid] = {
            "kind": kind,
            "username": username.lower(),
            "challenge": challenge,
            "ts": int(time.time()),
            "ttl": ttl,
        }
        return cid

    def take_challenge(self, cid: str, kind: str):
        ch = self._data["challenges"].get(cid)
        if not ch or ch["kind"] != kind:
            return None
        if time.time() - ch["ts"] > ch.get("ttl", 300):
            return None
        return ch

    def drop_challenge(self, cid: str):
        self._data["challenges"].pop(cid, None)

    def _cleanup_challenges(self):
        now = time.time()
        expired = [
            cid
            for cid, c in self._data["challenges"].items()
            if now - c["ts"] > c.get("ttl", 300)
        ]
        for cid in expired:
            self._data["challenges"].pop(cid, None)

    # --- contexto ---------------------------------------------------------- #
    def __enter__(self):
        self._lock.acquire()
        return self

    def __exit__(self, *exc):
        try:
            self._save()
        finally:
            self._lock.release()
        return False

    def snapshot(self):
        with self._lock:
            return {
                "users": len(self._data["users"]),
                "credentials": sum(
                    len(u["credentials"]) for u in self._data["users"].values()
                ),
                "pending_challenges": len(self._data["challenges"]),
            }


# --------------------------------------------------------------------------- #
# Criptografia — verificação de chave pública COSE
# --------------------------------------------------------------------------- #
def _public_key_from_cose(cose_key: dict):
    kty = cose_key.get(1)
    alg = cose_key.get(3)
    if kty == 2:  # EC2 (EC)
        curve = cose_key.get(-1)
        if curve != 1:
            raise ValueError("Curva EC não suportada (esperado P-256).")
        x = cose_key[-2]
        y = cose_key[-3]
        return ec.EllipticCurvePublicNumbers(
            int.from_bytes(x, "big"),
            int.from_bytes(y, "big"),
            ec.SECP256R1(),
        ).public_key()
    if kty == 3:  # RSA
        n = cose_key.get(-1)
        e = cose_key.get(-2)
        return rsa.RSAPublicNumbers(
            int.from_bytes(e, "big"),
            int.from_bytes(n, "big"),
        ).public_key()
    raise ValueError(f"Tipo de chave COSE não suportado (kty={kty}, alg={alg}).")


def _verify_signature(public_key, signature: bytes, data: bytes, alg: int):
    try:
        if alg == -7:  # ES256
            public_key.verify(signature, data, ec.ECDSA(hashes.SHA256()))
        elif alg == -257:  # RS256
            public_key.verify(
                signature, data, padding.PKCS1v15(), hashes.SHA256()
            )
        else:
            raise ValueError(
                f"Algoritmo de assinatura não suportado (alg={alg})."
            )
    except InvalidSignature as exc:
        raise ValueError("Assinatura da passkey inválida.") from exc


def _parse_auth_data(auth_data: bytes):
    if len(auth_data) < 37:
        raise ValueError("authenticatorData muito curto.")
    rp_id_hash = auth_data[0:32]
    flags = auth_data[32]
    sign_count = int.from_bytes(auth_data[33:37], "big")
    rest = auth_data[37:]
    return rp_id_hash, flags, sign_count, rest


def _parse_attested_credential_data(rest: bytes):
    if len(rest) < 18:
        raise ValueError("attestedCredentialData incompleto.")
    aaguid = rest[0:16]
    cred_id_len = int.from_bytes(rest[16:18], "big")
    credential_id = rest[18 : 18 + cred_id_len]
    pubkey_bytes = rest[18 + cred_id_len :]
    cose_key = cbor2.loads(pubkey_bytes)
    return aaguid, credential_id, cose_key


def _validate_client_data(client_data_b64: str, expected_type: str,
                          expected_challenge: str, rp_id: str):
    client_data = json.loads(b64url_decode(client_data_b64).decode("utf-8"))
    if client_data.get("type") != expected_type:
        raise ValueError(
            f"clientData.type inválido: {client_data.get('type')} "
            f"(esperado {expected_type})."
        )
    # Compara o challenge (base64url, sem padding).
    if client_data.get("challenge") != expected_challenge:
        raise ValueError("Challenge não confere.")
    origin = client_data.get("origin") or ""
    host = urlparse(origin).hostname or ""
    if not _host_matches_rp(host, rp_id):
        raise ValueError(
            f"Origem '{origin}' não autorizada para o RP ID '{rp_id}'."
        )
    return client_data


def _host_matches_rp(host: str, rp_id: str) -> bool:
    if not host or not rp_id:
        return False
    return host == rp_id or host.endswith("." + rp_id)


# --------------------------------------------------------------------------- #
# Fluxo de REGISTRO
# --------------------------------------------------------------------------- #
def create_registration_options(store: PasskeyStore, username: str,
                                display_name: str, rp_id: str, rp_name: str):
    with store:
        user = store.upsert_user(username, display_name)
        challenge = b64url_encode(secrets.token_bytes(32))
        cid = store.put_challenge("register", username, challenge)
        exclude = [
            {"type": "public-key", "id": c["id"], "transports": c.get("transports", [])}
            for c in user["credentials"]
        ]
        options = {
            "challenge": challenge,
            "rp": {"id": rp_id, "name": rp_name},
            "user": {
                "id": user["userHandle"],
                "name": username,
                "displayName": user["displayName"],
            },
            "pubKeyCredParams": [
                {"type": "public-key", "alg": -7},
                {"type": "public-key", "alg": -257},
            ],
            "timeout": 60000,
            "attestation": "none",
            "authenticatorSelection": {
                "requireResidentKey": True,
                "residentKey": "required",
                "userVerification": "preferred",
                "authenticatorAttachment": "platform",
            },
            "excludeCredentials": exclude,
        }
        return cid, options


def verify_registration(store: PasskeyStore, cid: str, credential: dict,
                        rp_id: str):
    with store:
        ch = store.take_challenge(cid, "register")
        if not ch:
            raise ValueError("Desafio de registro inválido ou expirado.")
        username = ch["username"]

        client_data = _validate_client_data(
            credential["response"]["clientDataJSON"],
            "webauthn.create",
            ch["challenge"],
            rp_id,
        )
        auth_data = b64url_decode(credential["response"]["attestationObject"])
        attestation = cbor2.loads(auth_data)
        raw_auth = attestation["authData"]
        rp_id_hash, flags, sign_count, rest = _parse_auth_data(raw_auth)

        import hashlib
        if rp_id_hash != hashlib.sha256(rp_id.encode("utf-8")).digest():
            raise ValueError("rpIdHash não confere com o RP ID.")

        if not (flags & 0x01):
            raise ValueError("Flag UP (user present) ausente.")
        if not (flags & 0x40):
            raise ValueError("Atestação (flag AT) ausente.")

        _, credential_id, cose_key = _parse_attested_credential_data(rest)

        cred = {
            "id": b64url_encode(credential_id),
            "publicKey": _cose_to_json(cose_key),
            "signCount": sign_count,
            "transports": credential["response"].get("transports", []),
            "createdAt": int(time.time()),
        }
        store.add_credential(username, cred)
        store.drop_challenge(cid)
        # Retorna também o `origin` validado (para log).
        return username, client_data.get("origin", "")


def _cose_to_json(cose_key: dict) -> dict:
    """Serializa o mapa COSE (bytes → base64url) para guardar em JSON."""
    def enc(v):
        if isinstance(v, bytes):
            return {"__b64": b64url_encode(v)}
        if isinstance(v, dict):
            return {str(k): enc(val) for k, val in v.items()}
        return v
    return enc(cose_key)


def _cose_from_json(obj: dict) -> dict:
    def dec(v):
        if isinstance(v, dict):
            if set(v.keys()) == {"__b64"}:
                return b64url_decode(v["__b64"])
            return {int(k) if k.lstrip("-").isdigit() else k: dec(val)
                    for k, val in v.items()}
        return v
    return dec(obj)


# --------------------------------------------------------------------------- #
# Fluxo de AUTENTICAÇÃO
# --------------------------------------------------------------------------- #
def create_authentication_options(store: PasskeyStore, username: str,
                                  rp_id: str):
    with store:
        user = store.user(username)
        if not user or not user["credentials"]:
            raise ValueError(
                "Nenhuma passkey encontrada para este usuário."
            )
        challenge = b64url_encode(secrets.token_bytes(32))
        cid = store.put_challenge("login", username, challenge)
        options = {
            "challenge": challenge,
            "rpId": rp_id,
            "timeout": 60000,
            "userVerification": "preferred",
            "allowCredentials": [
                {
                    "type": "public-key",
                    "id": c["id"],
                    "transports": c.get("transports", []),
                }
                for c in user["credentials"]
            ],
        }
        return cid, options


def verify_authentication(store: PasskeyStore, cid: str, credential: dict,
                          rp_id: str):
    with store:
        ch = store.take_challenge(cid, "login")
        if not ch:
            raise ValueError("Desafio de login inválido ou expirado.")

        credential_id = credential.get("id") or credential.get("rawId")
        username, user, stored = store.find_credential(credential_id)
        if stored is None:
            raise ValueError("Credencial não registrada.")

        client_data = _validate_client_data(
            credential["response"]["clientDataJSON"],
            "webauthn.get",
            ch["challenge"],
            rp_id,
        )

        auth_data = b64url_decode(credential["response"]["authenticatorData"])
        rp_id_hash, flags, sign_count, _ = _parse_auth_data(auth_data)

        import hashlib
        if rp_id_hash != hashlib.sha256(rp_id.encode("utf-8")).digest():
            raise ValueError("rpIdHash não confere com o RP ID.")
        if not (flags & 0x01):
            raise ValueError("Flag UP (user present) ausente.")

        client_data_hash = hashlib.sha256(
            b64url_decode(credential["response"]["clientDataJSON"])
        ).digest()
        signature_base = auth_data + client_data_hash

        cose_key = _cose_from_json(stored["publicKey"])
        alg = cose_key.get(3, -7)
        public_key = _public_key_from_cose(cose_key)
        signature = b64url_decode(credential["response"]["signature"])
        _verify_signature(public_key, signature, signature_base, alg)

        # Anti-replay (ignora se o autenticador não usa contador).
        if sign_count and stored.get("signCount") and sign_count <= stored["signCount"]:
            raise ValueError("Contador de assinatura inválido (possível replay).")
        stored["signCount"] = sign_count

        store.drop_challenge(cid)
        return user["username"], client_data.get("origin", "")


# --------------------------------------------------------------------------- #
# Digital Asset Links (Android)
# --------------------------------------------------------------------------- #
def assetlinks_json(package_name: str, fingerprints):
    """Gera o conteúdo de /.well-known/assetlinks.json."""
    return [
        {
            "relation": ["delegate_permission/common.get_login_creds"],
            "target": {
                "namespace": "android_app",
                "package_name": package_name,
                "sha256_cert_fingerprints": list(fingerprints),
            },
        }
    ]
