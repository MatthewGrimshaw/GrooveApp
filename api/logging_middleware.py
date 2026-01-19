"""
FastAPI middleware for request/response logging and tracing
"""

import logging
import time
import uuid
from typing import Callable

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """
    Middleware for logging all API requests and responses
    Adds operation_id, timing, and audit trail
    """

    def __init__(self, app: ASGIApp, logger: logging.Logger):
        super().__init__(app)
        self.logger = logger

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Generate unique operation ID for request tracing
        operation_id = str(uuid.uuid4())
        request.state.operation_id = operation_id

        # Get user ID (from auth header if available)
        user_id = request.headers.get("X-User-ID", "anonymous")
        request.state.user_id = user_id

        # Start timing
        start_time = time.time()

        # Log incoming request
        self.logger.info(
            f"REQUEST: {request.method} {request.url.path}",
            extra={
                "operation_id": operation_id,
                "user_id": user_id,
                "request_path": request.url.path,
                "method": request.method,
                "query_params": str(dict(request.query_params)),
                "client_ip": request.client.host if request.client else "unknown",
            },
        )

        # Process request
        try:
            response = await call_next(request)

            # Calculate duration
            duration_ms = int((time.time() - start_time) * 1000)

            # Log response
            self.logger.info(
                f"RESPONSE: {request.method} {request.url.path} | "
                f"Status: {response.status_code} | Duration: {duration_ms}ms",
                extra={
                    "operation_id": operation_id,
                    "user_id": user_id,
                    "request_path": request.url.path,
                    "status_code": response.status_code,
                    "duration_ms": duration_ms,
                },
            )

            # Add operation ID to response headers for client-side tracing
            response.headers["X-Operation-ID"] = operation_id

            return response

        except Exception as e:
            # Calculate duration even for errors
            duration_ms = int((time.time() - start_time) * 1000)

            # Log error
            self.logger.error(
                f"ERROR: {request.method} {request.url.path} | "
                f"Error: {str(e)} | Duration: {duration_ms}ms",
                extra={
                    "operation_id": operation_id,
                    "user_id": user_id,
                    "request_path": request.url.path,
                    "duration_ms": duration_ms,
                    "error": str(e),
                    "error_type": type(e).__name__,
                },
                exc_info=True,
            )

            # Re-raise to let FastAPI handle it
            raise


class DatabaseLoggingMiddleware:
    """
    Context manager for logging database operations
    """

    def __init__(self, logger: logging.Logger, operation: str, request: Request = None):
        self.logger = logger
        self.operation = operation
        self.request = request
        self.start_time = None

    def __enter__(self):
        self.start_time = time.time()
        operation_id = (
            getattr(self.request.state, "operation_id", "N/A")
            if self.request
            else "N/A"
        )
        user_id = (
            getattr(self.request.state, "user_id", "anonymous")
            if self.request
            else "system"
        )

        self.logger.debug(
            f"DB START: {self.operation}",
            extra={
                "operation_id": operation_id,
                "user_id": user_id,
                "db_operation": self.operation,
            },
        )
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        duration_ms = int((time.time() - self.start_time) * 1000)
        operation_id = (
            getattr(self.request.state, "operation_id", "N/A")
            if self.request
            else "N/A"
        )
        user_id = (
            getattr(self.request.state, "user_id", "anonymous")
            if self.request
            else "system"
        )

        if exc_type is None:
            self.logger.debug(
                f"DB SUCCESS: {self.operation} | Duration: {duration_ms}ms",
                extra={
                    "operation_id": operation_id,
                    "user_id": user_id,
                    "db_operation": self.operation,
                    "duration_ms": duration_ms,
                },
            )
        else:
            self.logger.error(
                f"DB ERROR: {self.operation} | Error: {str(exc_val)} | Duration: {duration_ms}ms",
                extra={
                    "operation_id": operation_id,
                    "user_id": user_id,
                    "db_operation": self.operation,
                    "duration_ms": duration_ms,
                    "error": str(exc_val),
                    "error_type": exc_type.__name__ if exc_type else "Unknown",
                },
                exc_info=True,
            )
