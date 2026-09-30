class AgentException(Exception):
    def __init__(self, message: str, error_code: str = "AGENT_ERROR"):
        self.message = message
        self.error_code = error_code
        super().__init__(message)

class StorageException(AgentException):
    def __init__(self, message: str):
        super().__init__(message, error_code="STORAGE_ERROR")

class CupsException(AgentException):
    def __init__(self, message: str):
        super().__init__(message, error_code="CUPS_ERROR")

class BackendCommunicationException(AgentException):
    def __init__(self, message: str):
        super().__init__(message, error_code="BACKEND_COMMUNICATION_ERROR")

class OtpReleaseException(AgentException):
    def __init__(self, message: str, error_code: str = "INVALID_OTP"):
        super().__init__(message, error_code=error_code)
