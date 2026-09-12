import hashlib
import io
from uuid import uuid4

from PIL import Image, UnidentifiedImageError

from apps.core.services import DomainError
from apps.programs.uploads import private_path

from .models import AccountSignature

MAX_SIGNATURE_BYTES = 2_000_000
MAX_SIGNATURE_PIXELS = 4_000_000


def normalize_signature(content):
    if not content or len(content) > MAX_SIGNATURE_BYTES:
        raise DomainError(
            "PAYLOAD_TOO_LARGE", "Signature must contain 1 to 2,000,000 bytes.", 413
        )
    try:
        with Image.open(io.BytesIO(content)) as image:
            if (
                image.format not in ["PNG", "JPEG"]
                or image.width * image.height > MAX_SIGNATURE_PIXELS
            ):
                raise DomainError(
                    "UNSUPPORTED_MEDIA_TYPE",
                    "Use a PNG or JPEG signature up to 4 megapixels.",
                    415,
                )
            image.load()
            normalized = image.convert("RGBA")
            normalized.thumbnail((1600, 800))
            stream = io.BytesIO()
            normalized.save(stream, format="PNG")
            return stream.getvalue()
    except (UnidentifiedImageError, OSError):
        raise DomainError(
            "UNSUPPORTED_MEDIA_TYPE", "The signature is not a valid image.", 415
        )


def write_signature_version(user, content):
    key = "signatures/" + uuid4().hex + ".png"
    target = private_path(key)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(content)
    try:
        signature = AccountSignature.objects.create(
            user=user,
            storage_key=key,
            sha256=hashlib.sha256(content).hexdigest(),
        )
    except Exception:
        target.unlink(missing_ok=True)
        raise
    return signature
