"""Verifies Firebase ID tokens (Google sign-in and email/password with a verified email)."""
import jwt
from jwt import PyJWKClient

JWKS_URL = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"
_client: PyJWKClient | None = None


class FirebaseAuthError(Exception):
    pass


def _jwks() -> PyJWKClient:
    global _client
    if _client is None:
        _client = PyJWKClient(JWKS_URL, cache_keys=True, lifespan=3600)
    return _client


def verify_id_token(token: str, project_id: str) -> dict:
    """Checks signature, expiry, audience and issuer. Returns the token claims."""
    try:
        key = _jwks().get_signing_key_from_jwt(token).key
        claims = jwt.decode(token, key, algorithms=["RS256"], audience=project_id,
                            issuer=f"https://securetoken.google.com/{project_id}", leeway=10)
    except Exception as e:  # bad signature, expired, wrong project, network error...
        raise FirebaseAuthError(str(e)) from e
    if not claims.get("sub"):
        raise FirebaseAuthError("token has no subject")
    return claims
