from typing import Literal
from pydantic import BaseModel, ConfigDict, Field

class AgentReleaseRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    otp: str = Field(pattern=r'^[0-9]{6}$')

class AgentJobStatusUpdate(BaseModel):
    model_config = ConfigDict(extra='forbid')
    status: Literal['PRINTING', 'COMPLETED', 'FAILED']
    claimToken: str = Field(min_length=32, max_length=128)
    cupsJobId: str | None = Field(default=None, max_length=128)
    errorCode: str | None = Field(default=None, max_length=128)
    message: str | None = Field(default=None, max_length=500)

class AgentJobResponse(BaseModel):
    jobId: str
    orderId: str

class AgentReleaseResponse(BaseModel):
    jobId: str
    orderId: str
    status: str
