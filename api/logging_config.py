"""
Logging configuration for GrooveApp API
Supports both local development and Azure Application Insights
"""

import logging
import sys
import os
from typing import Optional
from azure.monitor.opentelemetry import configure_azure_monitor


class LogLevelConfig:
    """Log level configuration based on environment variable"""

    LEVELS = {
        "OFF": logging.CRITICAL + 1,  # Disable all logging
        "ERROR": logging.ERROR,
        "WARNING": logging.WARNING,
        "INFO": logging.INFO,
        "ON": logging.INFO,  # Alias for INFO
        "VERBOSE": logging.DEBUG,
        "DEBUG": logging.DEBUG,
    }

    @classmethod
    def get_level(cls, level_name: str = "INFO") -> int:
        """Get logging level from string name"""
        return cls.LEVELS.get(level_name.upper(), logging.INFO)


class StructuredFormatter(logging.Formatter):
    """Structured logging formatter for better queryability"""

    def format(self, record: logging.LogRecord) -> str:
        # Add custom fields to log record
        if not hasattr(record, "operation_id"):
            record.operation_id = "N/A"
        if not hasattr(record, "user_id"):
            record.user_id = "anonymous"
        if not hasattr(record, "request_path"):
            record.request_path = "N/A"
        if not hasattr(record, "duration_ms"):
            record.duration_ms = 0

        return super().format(record)


def configure_logging(
    app_insights_connection_string: Optional[str] = None,
    log_level: str = "INFO",
    service_name: str = "grooveapp-api",
) -> logging.Logger:
    """
    Configure application logging with Azure Application Insights support

    Args:
        app_insights_connection_string: Application Insights connection string (optional for local dev)
        log_level: Log level (OFF, ERROR, WARNING, INFO/ON, VERBOSE/DEBUG)
        service_name: Service name for log identification

    Returns:
        Configured logger instance
    """

    # Get log level from config
    level = LogLevelConfig.get_level(log_level)

    # Create root logger
    logger = logging.getLogger(service_name)
    logger.setLevel(level)
    logger.handlers.clear()  # Remove existing handlers

    # Console handler for local development
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)

    # Format for console output
    console_format = StructuredFormatter(
        fmt="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s | "
        "operation_id=%(operation_id)s user=%(user_id)s path=%(request_path)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    console_handler.setFormatter(console_format)
    logger.addHandler(console_handler)

    # Azure Application Insights configuration (only if connection string provided)
    if app_insights_connection_string and log_level.upper() != "OFF":
        try:
            # Configure Azure Monitor OpenTelemetry with Live Metrics and Performance Counters
            configure_azure_monitor(
                connection_string=app_insights_connection_string,
                enable_live_metrics=True,  # Enable Live Metrics for real-time monitoring
                enable_standard_metrics=True,  # Enable performance counters (CPU, memory, request rate, etc.)
                logger_name=service_name,
                resource_attributes={
                    "service.name": service_name,
                    "service.instance.id": os.getenv("WEBSITE_INSTANCE_ID", "local"),
                },
            )

            logger.info(
                "Application Insights with Live Metrics enabled",
                extra={"operation_id": "startup", "request_path": "/init"},
            )

        except Exception as e:
            logger.warning(
                f"Failed to configure Application Insights: {e}. Using console logging only.",
                extra={"operation_id": "startup", "request_path": "/init"},
            )
    else:
        if log_level.upper() != "OFF":
            logger.info(
                "Running in local mode - Application Insights disabled",
                extra={"operation_id": "startup", "request_path": "/init"},
            )

    return logger


def get_tracer(
    app_insights_connection_string: Optional[str] = None, sample_rate: float = 1.0
) -> Optional[object]:
    """
    Get tracer for distributed tracing (deprecated - now handled by configure_azure_monitor)

    Args:
        app_insights_connection_string: Application Insights connection string
        sample_rate: Sampling rate (0.0 to 1.0, default 1.0 = 100%)

    Returns:
        None - tracing is automatically configured by configure_azure_monitor
    """
    logging.warning(
        "get_tracer is deprecated - tracing is now automatic with configure_azure_monitor"
    )
    return None


def create_audit_log(
    logger: logging.Logger,
    event_type: str,
    user_id: str,
    operation_id: str,
    details: dict,
    request_path: str = "N/A",
    duration_ms: int = 0,
):
    """
    Create structured audit log entry

    Args:
        logger: Logger instance
        event_type: Type of event (e.g., 'API_REQUEST', 'DB_QUERY', 'ERROR')
        user_id: User identifier
        operation_id: Request/operation identifier
        details: Additional details dictionary
        request_path: API path
        duration_ms: Operation duration in milliseconds
    """
    logger.info(
        f"AUDIT: {event_type} | {details}",
        extra={
            "event_type": event_type,
            "user_id": user_id,
            "operation_id": operation_id,
            "request_path": request_path,
            "duration_ms": duration_ms,
            "details": str(details),
        },
    )
