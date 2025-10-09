"""Ferramentas para otimização de agenda de plantão."""

from __future__ import annotations

from os import PathLike
from typing import TYPE_CHECKING, Any, Dict, Optional

if TYPE_CHECKING:  # pragma: no cover
    from .optimizer import OptimizationResult as OptimizationResultType
    from .icloud import ICloudConfig as ICloudConfigType

__all__ = [
    "OptimizationResult",
    "load_configuration",
    "optimize_schedule",
    "ICloudConfig",
    "load_icloud_config_from_env",
    "push_result_to_icloud",
    "ICloudIntegrationError",
]


def load_configuration(path: str | PathLike[str]) -> Dict[str, Any]:
    from .optimizer import load_configuration as _load_configuration

    return _load_configuration(path)


def optimize_schedule(*args: Any, **kwargs: Any):
    from .optimizer import optimize_schedule as _optimize_schedule

    return _optimize_schedule(*args, **kwargs)


def __getattr__(name: str):  # pragma: no cover - encaminhamento dinâmico
    if name == "OptimizationResult":
        from .optimizer import OptimizationResult

        return OptimizationResult
    if name == "ICloudConfig":
        from .icloud import ICloudConfig

        return ICloudConfig
    if name == "ICloudIntegrationError":
        from .icloud import ICloudIntegrationError

        return ICloudIntegrationError
    raise AttributeError(name)


def load_icloud_config_from_env() -> Optional["ICloudConfigType"]:
    from .icloud import load_config_from_env as _load

    return _load()


def push_result_to_icloud(
    result: "OptimizationResultType",
    config: "ICloudConfigType",
    *,
    timezone_name: Optional[str] = None,
    clear_existing: bool = True,
) -> int:
    from .icloud import connect as _connect, export_result as _export

    calendar = _connect(config)
    return _export(result, calendar, timezone_name=timezone_name, clear_existing=clear_existing)
