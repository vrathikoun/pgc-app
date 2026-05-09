import os
import uuid
from google.cloud import storage

BUCKET_NAME = os.getenv("GCP_BUCKET_NAME", "pgcupload")

_storage_client = storage.Client()
_bucket = _storage_client.bucket(BUCKET_NAME)


def upload_profile_picture(image_bytes: bytes, extension: str = "jpg") -> str:
    extension = extension.lower().replace(".", "")
    if extension == "jpeg":
        content_type = "image/jpeg"
    elif extension == "png":
        content_type = "image/png"
    elif extension == "webp":
        content_type = "image/webp"
    else:
        extension = "jpg"
        content_type = "image/jpeg"

    filename = f"profile_pictures/{uuid.uuid4().hex}.{extension}"
    blob = _bucket.blob(filename)

    blob.upload_from_string(
        image_bytes,
        content_type=content_type,
    )

    return f"https://storage.googleapis.com/{BUCKET_NAME}/{filename}"