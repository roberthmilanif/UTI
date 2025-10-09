"""Integração opcional com calendários do iCloud via CalDAV."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import os
import uuid
from typing import Iterable, Optional

try:  # Dependência opcional
    import caldav  # type: ignore
except Exception:  # pragma: no cover - caso sem caldav instalado
    caldav = None

from .optimizer import OptimizationResult, Shift

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover - compatibilidade Python < 3.9
    ZoneInfo = None  # type: ignore


class ICloudIntegrationError(RuntimeError):
    """Erro lançado quando a integração com o iCloud falha."""


@dataclass
class ICloudConfig:
    """Parâmetros necessários para conectar ao iCloud."""

    username: str
    app_password: str
    calendar: str
    server_url: str = "https://caldav.icloud.com/"


def _require_caldav() -> None:
    if caldav is None:  # pragma: no cover - apenas quando a dependência não está presente
        raise ICloudIntegrationError(
            "Integração indisponível: instale o pacote 'caldav' para usar o iCloud."
        )


def load_config_from_env() -> Optional[ICloudConfig]:
    """Cria configuração a partir de variáveis de ambiente padrão."""

    username = os.getenv("PLANTAO_ICLOUD_USER")
    app_password = os.getenv("PLANTAO_ICLOUD_APP_PASSWORD")
    calendar = os.getenv("PLANTAO_ICLOUD_CALENDAR")

    if not (username and app_password and calendar):
        return None

    server_url = os.getenv("PLANTAO_ICLOUD_SERVER", "https://caldav.icloud.com/")
    return ICloudConfig(username=username, app_password=app_password, calendar=calendar, server_url=server_url)


def connect(config: ICloudConfig) -> "caldav.Calendar":
    """Retorna o calendário solicitado no iCloud."""

    _require_caldav()
    client = caldav.DAVClient(url=config.server_url, username=config.username, password=config.app_password)
    principal = client.principal()

    calendars = principal.calendars()
    for calendar in calendars:
        if calendar.name == config.calendar:
            return calendar

    raise ICloudIntegrationError(
        "Calendário não encontrado. Crie-o previamente no iCloud ou ajuste o nome informado."
    )


def _localize(dt: datetime, tz_name: Optional[str]) -> datetime:
    if tz_name is None:
        return dt if dt.tzinfo is not None else dt.replace(tzinfo=timezone.utc)

    if ZoneInfo is None:
        raise ICloudIntegrationError(
            "zoneinfo indisponível neste interpretador. Utilize Python 3.9+ ou forneça datetimes com timezone."
        )

    tz = ZoneInfo(tz_name)
    if dt.tzinfo is None:
        return dt.replace(tzinfo=tz)
    return dt.astimezone(tz)


def _format_dt(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _build_event(professional: str, shift: Shift, tz_name: Optional[str]) -> str:
    start = _localize(shift.start, tz_name)
    end = _localize(shift.end, tz_name)
    uid = f"{shift.identifier}-{uuid.uuid4()}@plantao-optimizer"
    dtstamp = _format_dt(datetime.utcnow().replace(tzinfo=timezone.utc))
    dtstart = _format_dt(start)
    dtend = _format_dt(end)
    summary = f"Plantão - {professional}"
    description = (
        f"Profissional: {professional}\n"
        f"Início: {start.isoformat()}\n"
        f"Fim: {end.isoformat()}\n"
        f"ID do plantão: {shift.identifier}"
    )

    return (
        "BEGIN:VCALENDAR\n"
        "VERSION:2.0\n"
        "PRODID:-//plantao-optimizer//iCloud//PT-BR\n"
        "BEGIN:VEVENT\n"
        f"UID:{uid}\n"
        f"DTSTAMP:{dtstamp}\n"
        f"DTSTART:{dtstart}\n"
        f"DTEND:{dtend}\n"
        f"SUMMARY:{summary}\n"
        f"DESCRIPTION:{description}\n"
        f"X-PLANTAO-ID:{shift.identifier}\n"
        "END:VEVENT\n"
        "END:VCALENDAR\n"
    )


def remove_existing_events(calendar: "caldav.Calendar", shift_ids: Iterable[str]) -> None:
    """Remove eventos que contenham IDs informados no campo X-PLANTAO-ID."""

    _require_caldav()
    shift_ids = set(shift_ids)
    if not shift_ids:
        return

    for event in calendar.events():  # pragma: no branch - loop simples
        data = getattr(event, "data", "")
        if not data:
            continue
        if any(f"X-PLANTAO-ID:{shift_id}" in data for shift_id in shift_ids):
            event.delete()


def export_result(
    result: OptimizationResult,
    calendar: "caldav.Calendar",
    *,
    timezone_name: Optional[str] = None,
    clear_existing: bool = True,
) -> int:
    """Exporta o resultado da otimização para o calendário especificado.

    Returns:
        Número de eventos criados.
    """

    _require_caldav()
    if clear_existing:
        remove_existing_events(calendar, result.assignments.keys())

    created = 0
    for professional, shift in result.iter_assigned_shifts():
        ics = _build_event(professional, shift, timezone_name)
        calendar.save_event(ics)
        created += 1
    return created
