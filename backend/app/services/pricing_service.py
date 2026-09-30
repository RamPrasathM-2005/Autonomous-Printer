from typing import List, Optional
from app.config.settings import settings
from app.utils.errors import AppException
from fastapi import status

class PricingService:
    @staticmethod
    def parse_and_validate_page_range(page_range_str: Optional[str], total_doc_pages: int) -> List[int]:
        """
        Parses page range strings such as '1-5', '1-3,7-9', '1,3,5-7'.
        Validates that all page numbers are in [1, total_doc_pages].
        Deduplicates and returns sorted list of 1-based page numbers.
        """
        if not page_range_str or not page_range_str.strip():
            return list(range(1, total_doc_pages + 1))

        clean_str = page_range_str.strip().lower()
        if clean_str in ["all", "none"]:
            return list(range(1, total_doc_pages + 1))
        if clean_str == "odd":
            odd_pages = [p for p in range(1, total_doc_pages + 1) if p % 2 != 0]
            return odd_pages if odd_pages else [1]
        if clean_str == "even":
            even_pages = [p for p in range(1, total_doc_pages + 1) if p % 2 == 0]

            if not even_pages:
                raise AppException(400, 'INVALID_PAGE_RANGE', 'Document has no even pages.')
            return even_pages

        pages_set = set()
        parts = [p.strip() for p in page_range_str.split(",") if p.strip()]

        if not parts:
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="INVALID_PAGE_RANGE",
                message="Page range format is invalid."
            )

        for part in parts:
            if "-" in part:
                sub_parts = part.split("-")
                if len(sub_parts) != 2:
                    raise AppException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        error_code="INVALID_PAGE_RANGE",
                        message=f"Invalid page range token: '{part}'"
                    )
                try:
                    start_page = int(sub_parts[0].strip())
                    end_page = int(sub_parts[1].strip())
                except ValueError:
                    raise AppException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        error_code="INVALID_PAGE_RANGE",
                        message=f"Non-numeric page range token: '{part}'"
                    )

                if start_page < 1 or end_page < 1:
                    raise AppException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        error_code="INVALID_PAGE_RANGE",
                        message="Page numbers must be 1 or greater."
                    )
                if start_page > end_page:
                    raise AppException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        error_code="INVALID_PAGE_RANGE",
                        message=f"Start page {start_page} cannot exceed end page {end_page}."
                    )
                if end_page > total_doc_pages:
                    raise AppException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        error_code="INVALID_PAGE_RANGE",
                        message=f"Page {end_page} exceeds document total page count of {total_doc_pages}."
                    )
                pages_set.update(range(start_page, end_page + 1))
            else:
                try:
                    page_num = int(part.strip())
                except ValueError:
                    raise AppException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        error_code="INVALID_PAGE_RANGE",
                        message=f"Non-numeric page token: '{part}'"
                    )
                if page_num < 1:
                    raise AppException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        error_code="INVALID_PAGE_RANGE",
                        message="Page numbers must be 1 or greater."
                    )
                if page_num > total_doc_pages:
                    raise AppException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        error_code="INVALID_PAGE_RANGE",
                        message=f"Page {page_num} exceeds document total page count of {total_doc_pages}."
                    )
                pages_set.add(page_num)

        if not pages_set:
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="INVALID_PAGE_RANGE",
                message="No valid pages selected."
            )

        return sorted(list(pages_set))

    @staticmethod
    def calculate_price(selected_pages_count, copies, is_colour=False, per_page_rate=None, base_fee=None):
        from decimal import Decimal, ROUND_HALF_UP
        if selected_pages_count < 1 or copies < 1 or copies > 100:
            raise AppException(400, 'INVALID_QUANTITY', 'Invalid print quantity.')
        rate = Decimal(str(per_page_rate)) if per_page_rate is not None else (
            settings.COLOR_PAGE_RATE if is_colour else settings.PER_PAGE_RATE)
        fee = Decimal(str(base_fee)) if base_fee is not None else settings.BASE_FEE
        return (Decimal(selected_pages_count * copies) * rate + fee).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

pricing_service = PricingService()
