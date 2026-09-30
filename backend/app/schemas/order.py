from datetime import datetime
from typing import Optional, Dict, Any, List, Literal
from pydantic import BaseModel, Field, ConfigDict, model_validator
from app.db.models.order import OrderStatus

class PrintSettingsSchema(BaseModel):
    model_config = ConfigDict(extra='forbid', populate_by_name=True)
    copies: int = Field(default=1, ge=1, le=100, strict=True)
    pageRange: Optional[str] = Field(default=None, max_length=1000)
    colour: bool = Field(default=False, strict=True)
    sides: Literal['one-sided', 'two-sided-long-edge', 'two-sided-short-edge'] = 'one-sided'
    paperSize: Literal['A4', 'Letter', 'Legal'] = 'A4'
    orientation: Literal['portrait', 'landscape'] = 'portrait'

    @model_validator(mode='before')
    @classmethod
    def aliases(cls, value):
        if not isinstance(value, dict): return value
        value = dict(value)
        for source, dest in [('page_range', 'pageRange'), ('paper_size', 'paperSize')]:
            if source in value and dest not in value: value[dest] = value.pop(source)
        for key in ('colorMode', 'color_mode'):
            if key in value:
                mode = value.pop(key)
                if mode not in ('COLOR', 'MONOCHROME', 'GRAYSCALE'):
                    raise ValueError('Unsupported color mode')
                if 'colour' in value: raise ValueError('Duplicate color setting')
                value['colour'] = mode == 'COLOR'
        if 'duplex' in value:
            duplex = value.pop('duplex')
            if not isinstance(duplex, bool): raise ValueError('Duplex must be boolean')
            if 'sides' in value: raise ValueError('Duplicate sides setting')
            value['sides'] = 'two-sided-long-edge' if duplex else 'one-sided'
        return value

class OrderItemConfig(BaseModel):
    model_config = ConfigDict(extra='forbid', populate_by_name=True)
    documentId: str = Field(min_length=1, max_length=64)
    settings: PrintSettingsSchema = Field(default_factory=PrintSettingsSchema)

    @model_validator(mode='before')
    @classmethod
    def aliases(cls, value):
        if isinstance(value, dict):
            value = dict(value)
            if 'document_id' in value and 'documentId' not in value:
                value['documentId'] = value.pop('document_id')
        return value

class OrderCreateRequest(BaseModel):
    model_config = ConfigDict(extra='forbid', populate_by_name=True)
    documentId: Optional[str] = Field(default=None, max_length=64)
    printServerId: str = Field(min_length=1, max_length=64)
    settings: PrintSettingsSchema = Field(default_factory=PrintSettingsSchema)
    items: Optional[List[OrderItemConfig]] = Field(default=None, min_length=1, max_length=10)

    @model_validator(mode='before')
    @classmethod
    def aliases(cls, value):
        if not isinstance(value, dict): return value
        value = dict(value)
        for source, dest in [('document_id', 'documentId'), ('print_server_id', 'printServerId'), ('print_settings', 'settings')]:
            if source in value and dest not in value: value[dest] = value.pop(source)
        return value

class OrderResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True, from_attributes=True)

    id: str
    userId: Optional[int] = Field(default=None, alias="userId", serialization_alias="userId")
    documentId: str = Field(..., alias="documentId", serialization_alias="documentId")
    printServerId: str = Field(..., alias="printServerId", serialization_alias="printServerId")
    printSettings: Dict[str, Any] = Field(..., alias="printSettings", serialization_alias="printSettings")
    totalPages: int = Field(..., alias="totalPages", serialization_alias="totalPages")
    copies: int
    amount: float
    currency: str
    status: OrderStatus
    createdAt: datetime = Field(..., alias="createdAt", serialization_alias="createdAt")

    def __init__(self, **data):
        if "user_id" in data and "userId" not in data:
            data["userId"] = data.pop("user_id")
        if "document_id" in data and "documentId" not in data:
            data["documentId"] = data.pop("document_id")
        if "print_server_id" in data and "printServerId" not in data:
            data["printServerId"] = data.pop("print_server_id")
        if "print_settings" in data and "printSettings" not in data:
            data["printSettings"] = data.pop("print_settings")
        if "total_pages" in data and "totalPages" not in data:
            data["totalPages"] = data.pop("total_pages")
        if "created_at" in data and "createdAt" not in data:
            data["createdAt"] = data.pop("created_at")
        super().__init__(**data)

class OTPResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    orderId: str = Field(..., alias="orderId", serialization_alias="orderId")
    otp: str
    expiresAt: datetime = Field(..., alias="expiresAt", serialization_alias="expiresAt")

    def __init__(self, **data):
        if "order_id" in data and "orderId" not in data:
            data["orderId"] = data.pop("order_id")
        if "expires_at" in data and "expiresAt" not in data:
            data["expiresAt"] = data.pop("expires_at")
        super().__init__(**data)
