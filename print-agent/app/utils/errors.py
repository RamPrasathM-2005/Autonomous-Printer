class AgentException(Exception):
    def __init__(self, message: str, error_code: str = "AGENT_ERROR"):
        self.message = message
        self.error_code = error_code
        super().__init__(message)

class StorageException(AgentException):
    def __init__(self, message: str):
        super().__init__(message, error_code="STORAGE_ERROR")

class CupsException(AgentException):
    def __init__(self, message: str, error_code: str = "CUPS_ERROR"):
        super().__init__(message, error_code=error_code)

class BackendCommunicationException(AgentException):
    def __init__(self, message: str, error_code: str = "BACKEND_UNAVAILABLE", status_code: int = 503):
        self.status_code = status_code
        super().__init__(message, error_code=error_code)

class OTPReleaseException(AgentException):
    def __init__(self, message: str, error_code: str = "RELEASE_FAILED", status_code: int = 400):
        self.status_code = status_code
        super().__init__(message, error_code=error_code)

OtpReleaseException = OTPReleaseException
