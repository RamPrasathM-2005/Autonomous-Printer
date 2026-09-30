import os
import re
import uuid
from pathlib import Path
from typing import Tuple, List, Dict, Any
from fastapi import status
from PIL import Image
from pypdf import PdfReader

from app.utils.errors import AppException

SUPPORTED_MIME_TYPES = {
    "application/pdf": ".pdf",
    "image/jpeg": ".jpg",
    "image/png": ".png",
}

# Magic byte signatures
MAGIC_BYTES = {
    "pdf": b"%PDF-",
    "jpg": b"\xff\xd8\xff",
    "png": b"\x89PNG\r\n\x1a\n",
}

# Dangerous binary signatures (PE, ELF, Mach-O, Java Class) - stored as hex bytes
DANGEROUS_MAGIC_SIGNATURES = [
    (bytes.fromhex("4d5a"), "Windows PE Executable / DLL"),
    (bytes.fromhex("7f454c46"), "Linux ELF Binary"),
    (bytes.fromhex("feedface"), "Mach-O 32-bit"),
    (bytes.fromhex("feedfacf"), "Mach-O 64-bit"),
    (bytes.fromhex("cefaedfe"), "Mach-O Reverse 32-bit"),
    (bytes.fromhex("cffaedfe"), "Mach-O Reverse 64-bit"),
    (bytes.fromhex("cafebabe"), "Java Class / Mach-O Universal"),
]

# Disallowed malicious script tokens - compiled from hex byte sequences
DANGEROUS_PATTERNS = [
    (re.compile(bytes.fromhex("3c3f706870"), re.IGNORECASE), "Embedded PHP script"),
    (re.compile(bytes.fromhex("3c736372697074"), re.IGNORECASE), "Embedded Script tag"),
    (re.compile(bytes.fromhex("6576616c5c732a5c28"), re.IGNORECASE), "Dynamic eval trigger"),
    (re.compile(bytes.fromhex("706f7765727368656c6c"), re.IGNORECASE), "PowerShell execution token"),
    (re.compile(bytes.fromhex("23212f62696e2f"), re.IGNORECASE), "Unix shell script shebang"),
]

# PDF Triggerable Action Keys that pose security threats in print environments
DISALLOWED_PDF_ACTIONS = [
    bytes.fromhex("2f4c61756e6368"),        # /Launch
    bytes.fromhex("2f4a617661536372697074"),# /JavaScript
    bytes.fromhex("2f4a53"),                # /JS
    bytes.fromhex("2f456d62656464656446696c6573"), # /EmbeddedFiles
    bytes.fromhex("2f5375626d6974466f726d"),# /SubmitForm
    bytes.fromhex("2f496d706f727444617461"),# /ImportData
    bytes.fromhex("2f526963684d65646961"),  # /RichMedia
]


# Max image dimension limits to prevent Decompression Bomb (Pixel Flooding) attacks
MAX_IMAGE_WIDTH = 10000
MAX_IMAGE_HEIGHT = 10000
MAX_IMAGE_PIXELS = 50_000_000


def detect_file_type_from_header(first_bytes: bytes) -> str | None:
    if first_bytes.startswith(MAGIC_BYTES["pdf"]):
        return "application/pdf"
    if first_bytes.startswith(MAGIC_BYTES["png"]):
        return "image/png"
    if first_bytes.startswith(MAGIC_BYTES["jpg"]):
        return "image/jpeg"
    return None


def scan_for_malicious_content(file_path: Path) -> None:
    """
    Scans the entire file for known dangerous binary headers, executable code,
    web shells, and malicious script payload patterns.
    """
    file_size = file_path.stat().st_size
    # Read first 8KB for header inspection
    with open(file_path, "rb") as f:
        header = f.read(8192)

    # Check for direct dangerous magic signatures if not legitimate PDF/Image
    for magic, desc in DANGEROUS_MAGIC_SIGNATURES:
        if header.startswith(magic):
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="MALICIOUS_FILE_DETECTED",
                message=f"Security alert: File contains executable binary payload ({desc}) and was rejected."
            )

    # Chunked scan for dangerous script injections
    chunk_size = 65536
    with open(file_path, "rb") as f:
        overlap = b""
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            combined = overlap + chunk
            for pattern, threat_desc in DANGEROUS_PATTERNS:
                if pattern.search(combined):
                    raise AppException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        error_code="MALICIOUS_PAYLOAD_DETECTED",
                        message=f"Security alert: File contains disallowed triggerable code ({threat_desc}) and was rejected."
                    )
            overlap = chunk[-256:]


def verify_pdf_security_and_printability(file_path: Path) -> int:
    """
    Deeply parses the PDF file structure to ensure:
    1. It is valid and uncorrupted.
    2. It does not contain interactive executable actions (/Launch, /JS, /EmbeddedFiles).
    3. Every page has valid, non-zero printable dimensions.
    Returns the verified page count.
    """
    # 1. Byte-level scan for PDF exploit triggers
    with open(file_path, "rb") as f:
        pdf_bytes = f.read()

    for action in DISALLOWED_PDF_ACTIONS:
        if action in pdf_bytes:
            action_name = action.decode("ascii", errors="ignore").lstrip("/")
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="PDF_SECURITY_VIOLATION",
                message=f"Security alert: PDF contains interactive or executable trigger ({action_name}) and cannot be printed safely."
            )

    # 2. Structure and printability parsing using pypdf
    try:
        reader = PdfReader(str(file_path), strict=False)
        if reader.is_encrypted:
            # Check if empty password decrypts
            try:
                decrypted = reader.decrypt("")
                if not decrypted:
                    raise AppException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        error_code="PDF_PASSWORD_PROTECTED",
                        message="Password-protected PDFs cannot be printed without decryption."
                    )
            except Exception:
                raise AppException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    error_code="PDF_PASSWORD_PROTECTED",
                    message="Password-protected PDFs cannot be printed without decryption."
                )

        page_count = len(reader.pages)
        if page_count < 1:
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="INVALID_FILE",
                message="PDF contains no printable pages."
            )

        # Verify page dimensions are printable
        for idx, page in enumerate(reader.pages):
            try:
                box = page.mediabox
                width = float(box.width)
                height = float(box.height)
                if width <= 0 or height <= 0:
                    raise AppException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        error_code="UNPRINTABLE_PDF",
                        message=f"PDF page {idx + 1} has invalid or zero dimensions and cannot be printed."
                    )
            except Exception as e:
                if isinstance(e, AppException):
                    raise e
                raise AppException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    error_code="UNPRINTABLE_PDF",
                    message=f"Failed to read layout for PDF page {idx + 1}."
                )

        return page_count

    except AppException:
        raise
    except Exception as e:
        raise AppException(
            status_code=status.HTTP_400_BAD_REQUEST,
            error_code="INVALID_FILE",
            message="PDF file is corrupted, malformed, or unprintable."
        )


def verify_image_security_and_printability(file_path: Path) -> int:
    """
    Validates image structure, ensures image is uncorrupted and printable,
    and protects against decompression bomb attacks.
    Returns page count (1 for images).
    """
    try:
        with Image.open(str(file_path)) as img:
            # Check format is strictly JPEG or PNG
            if img.format not in ["JPEG", "PNG"]:
                raise AppException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    error_code="UNSUPPORTED_TYPE",
                    message=f"Image format {img.format} is not supported for printing. Only JPEG and PNG are allowed."
                )

            width, height = img.size
            if width <= 0 or height <= 0:
                raise AppException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    error_code="INVALID_FILE",
                    message="Image has invalid or zero dimensions."
                )

            total_pixels = width * height
            if width > MAX_IMAGE_WIDTH or height > MAX_IMAGE_HEIGHT or total_pixels > MAX_IMAGE_PIXELS:
                raise AppException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    error_code="IMAGE_TOO_LARGE",
                    message=f"Image dimensions ({width}x{height}) exceed maximum printable raster limit."
                )

            # Verify integrity
            img.verify()

        return 1

    except AppException:
        raise
    except Exception:
        raise AppException(
            status_code=status.HTTP_400_BAD_REQUEST,
            error_code="INVALID_FILE",
            message="Image file is corrupted, unreadable, or unprintable."
        )



def validate_file_content(header_bytes: bytes, filename: str, content_type: str | None) -> Tuple[str, str]:
    """
    Validates MIME type, extension, and binary header magic bytes.
    Returns (validated_mime, extension)
    """
    detected_mime = detect_file_type_from_header(header_bytes)
    if not detected_mime:
        raise AppException(
            status_code=status.HTTP_400_BAD_REQUEST,
            error_code="INVALID_FILE",
            message="File content does not match any supported format (PDF, JPG, PNG)."
        )

    # Check extension
    ext = os.path.splitext(filename)[1].lower()
    if ext == ".jpeg":
        ext = ".jpg"

    if detected_mime == "application/pdf" and ext != ".pdf":
        raise AppException(
            status_code=status.HTTP_400_BAD_REQUEST,
            error_code="UNSUPPORTED_TYPE",
            message=f"File extension {ext} does not match detected PDF format."
        )
    elif detected_mime == "image/jpeg" and ext not in [".jpg", ".jpeg"]:
        raise AppException(
            status_code=status.HTTP_400_BAD_REQUEST,
            error_code="UNSUPPORTED_TYPE",
            message=f"File extension {ext} does not match detected JPEG format."
        )
    elif detected_mime == "image/png" and ext != ".png":
        raise AppException(
            status_code=status.HTTP_400_BAD_REQUEST,
            error_code="UNSUPPORTED_TYPE",
            message=f"File extension {ext} does not match detected PNG format."
        )

    return detected_mime, ext


def generate_safe_filename(extension: str) -> str:
    """Generates a cryptographically random, collision-resistant filename."""
    if not extension.startswith("."):
        extension = "." + extension
    return f"{uuid.uuid4().hex}{extension}"


def resolve_safe_storage_path(storage_root: str | Path, storage_key: str) -> Path:
    """
    Resolves storage_root + storage_key and prevents directory traversal attacks.
    Ensures the target resides strictly inside storage_root.
    """
    root_path = Path(storage_root).resolve()
    clean_key = storage_key.lstrip("/\\")
    target_path = (root_path / clean_key).resolve()

    try:
        target_path.relative_to(root_path)
    except ValueError:
        raise AppException(
            status_code=status.HTTP_400_BAD_REQUEST,
            error_code="PATH_TRAVERSAL_DETECTED",
            message="Invalid storage path detected."
        )

    return target_path

