from fastapi import Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError

class AppError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400, details: list = None):
        self.code = code
        self.message = message
        self.status_code = status_code
        self.details = details

async def app_error_handler(request: Request, exc: AppError):
    content = {"detail": {"code": exc.code, "message": exc.message}}
    if exc.details:
        content["detail"]["details"] = exc.details
    return JSONResponse(status_code=exc.status_code, content=content)

async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": {"code": "validation_error", "message": "Input tidak valid", "details": exc.errors()}},
    )