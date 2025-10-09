"""Ferramenta simples para otimização de escala de plantões.

O módulo fornece uma heurística baseada em busca estocástica para distribuir
plantões entre profissionais, respeitando restrições básicas como descanso
mínimo, indisponibilidades e número máximo de plantões. O objetivo é obter uma
escala equilibrada que respeite preferências e limite sequências longas de
trabalho.

O algoritmo não garante solução ótima, mas executa múltiplas tentativas com
ordens diferentes e mantém o melhor resultado encontrado."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
import json
import math
import os
import random
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple

try:  # YAML é opcional
    import yaml  # type: ignore
except Exception:  # pragma: no cover - dependência opcional
    yaml = None


@dataclass(frozen=True)
class Shift:
    """Representa um plantão a ser preenchido."""

    identifier: str
    start: datetime
    end: datetime
    required_skills: Set[str] = field(default_factory=set)
    tags: Set[str] = field(default_factory=set)

    @property
    def duration(self) -> timedelta:
        return self.end - self.start

    @property
    def date(self) -> date:
        return self.start.date()


@dataclass
class Professional:
    """Profissional elegível para os plantões."""

    name: str
    skills: Set[str]
    max_shifts: Optional[int] = None
    min_rest_hours: Optional[float] = None
    unavailable: Set[date] = field(default_factory=set)
    preferred: Set[date] = field(default_factory=set)
    undesired: Set[date] = field(default_factory=set)


@dataclass
class OptimizationResult:
    assignments: Dict[str, str]
    unassigned: List[Shift]
    per_professional: Dict[str, Dict[str, object]]
    score: float
    iterations: int
    shifts: Dict[str, Shift] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, object]:
        return {
            "assignments": self.assignments,
            "unassigned": [shift.identifier for shift in self.unassigned],
            "per_professional": self.per_professional,
            "score": self.score,
            "iterations": self.iterations,
        }

    def iter_assigned_shifts(self) -> Iterable[Tuple[str, Shift]]:
        """Itera sobre os plantões atribuídos com seus respectivos profissionais."""

        for shift_id, professional in self.assignments.items():
            shift = self.shifts.get(shift_id)
            if shift is None:
                continue
            yield professional, shift


def _parse_datetime(value: str) -> datetime:
    try:
        return datetime.fromisoformat(value)
    except ValueError as exc:  # pragma: no cover - validação básica
        raise ValueError(f"Data/hora inválida: {value!r}") from exc


def _parse_date(value: str) -> date:
    try:
        return date.fromisoformat(value)
    except ValueError as exc:  # pragma: no cover - validação básica
        raise ValueError(f"Data inválida: {value!r}") from exc


def load_configuration(path: Path | str) -> Dict[str, object]:
    """Carrega arquivo de configuração em JSON ou YAML."""

    path = Path(path)
    raw = path.read_text(encoding="utf-8")
    if path.suffix.lower() in {".yaml", ".yml"}:
        if yaml is None:  # pragma: no cover - caso sem PyYAML
            raise RuntimeError(
                "PyYAML não está disponível. Instale o pacote para ler arquivos YAML."
            )
        data = yaml.safe_load(raw)
    else:
        data = json.loads(raw)

    if not isinstance(data, dict):  # pragma: no cover - validação
        raise ValueError("O arquivo de configuração deve conter um objeto JSON/YAML.")

    return data


def _prepare_shifts(raw_shifts: Sequence[Dict[str, object]]) -> List[Shift]:
    prepared: List[Shift] = []
    for item in raw_shifts:
        identifier = str(item["id"]) if "id" in item else None
        if not identifier:
            raise ValueError("Cada plantão precisa de um campo 'id'.")
        start = _parse_datetime(str(item["start"]))
        end = _parse_datetime(str(item["end"]))
        if end <= start:
            raise ValueError(
                f"O término do plantão '{identifier}' deve ser posterior ao início."
            )
        required_skills = set(map(str, item.get("skills", [])))
        tags = set(map(str, item.get("tags", [])))
        prepared.append(
            Shift(
                identifier=identifier,
                start=start,
                end=end,
                required_skills=required_skills,
                tags=tags,
            )
        )
    return prepared


def _prepare_professionals(raw_professionals: Sequence[Dict[str, object]]) -> List[Professional]:
    professionals: List[Professional] = []
    for item in raw_professionals:
        name = str(item.get("name"))
        if not name:
            raise ValueError("Todo profissional precisa de um nome.")
        skills = set(map(str, item.get("skills", [])))
        max_shifts = item.get("max_shifts")
        if max_shifts is not None:
            max_shifts = int(max_shifts)
        min_rest_hours = item.get("min_rest_hours")
        if min_rest_hours is not None:
            min_rest_hours = float(min_rest_hours)

        unavailable_raw = item.get("unavailable", [])
        preferred_raw = item.get("preferred", [])
        undesired_raw = item.get("undesired", [])
        if isinstance(unavailable_raw, dict):  # compatibilidade com configs antigas
            unavailable_raw = unavailable_raw.get("dates", [])
        if isinstance(preferred_raw, dict):
            preferred_raw = preferred_raw.get("dates", [])
        if isinstance(undesired_raw, dict):
            undesired_raw = undesired_raw.get("dates", [])

        unavailable = {_parse_date(str(val)) for val in unavailable_raw}
        preferred = {_parse_date(str(val)) for val in preferred_raw}
        undesired = {_parse_date(str(val)) for val in undesired_raw}

        professionals.append(
            Professional(
                name=name,
                skills=skills,
                max_shifts=max_shifts,
                min_rest_hours=min_rest_hours,
                unavailable=unavailable,
                preferred=preferred,
                undesired=undesired,
            )
        )
    return professionals


def _can_assign(
    professional: Professional,
    shift: Shift,
    assignments: Dict[str, List[Shift]],
    *,
    global_rest_hours: float,
    max_consecutive_days: Optional[int],
) -> bool:
    current = assignments.get(professional.name, [])
    if professional.max_shifts is not None and len(current) >= professional.max_shifts:
        return False

    if shift.date in professional.unavailable:
        return False

    if professional.skills and not shift.required_skills.issubset(professional.skills):
        return False

    last_shift = max(current, key=lambda s: s.end, default=None)
    min_rest = professional.min_rest_hours or global_rest_hours
    if last_shift is not None:
        hours_since_last = (shift.start - last_shift.end).total_seconds() / 3600
        if hours_since_last < min_rest:
            return False

    if max_consecutive_days is not None and max_consecutive_days > 0:
        dates = sorted({s.date for s in current})
        if not dates:
            dates = []
        # adicionar dia atual e verificar sequência
        dates.append(shift.date)
        dates = sorted(set(dates))
        if _longest_consecutive_streak(dates) > max_consecutive_days:
            return False

    return True


def _longest_consecutive_streak(dates: Sequence[date]) -> int:
    if not dates:
        return 0
    longest = 1
    current = 1
    for prev, nxt in zip(dates, dates[1:]):
        if nxt == prev + timedelta(days=1):
            current += 1
            longest = max(longest, current)
        else:
            current = 1
    return longest


def _evaluate_candidate(
    professional: Professional,
    shift: Shift,
    assignments: Dict[str, List[Shift]],
    *,
    fairness_target: float,
    preference_reward: float,
    undesired_penalty: float,
    balance_weight: float,
) -> float:
    current = assignments.get(professional.name, [])
    projected_count = len(current) + 1
    fairness_diff = projected_count - fairness_target
    penalty = balance_weight * (fairness_diff**2)

    shift_date = shift.date
    if professional.preferred and shift_date in professional.preferred:
        penalty -= preference_reward
    if professional.undesired and shift_date in professional.undesired:
        penalty += undesired_penalty

    # incentivar distribuição homogênea de horas
    total_hours = sum(s.duration.total_seconds() / 3600 for s in current)
    projected_hours = total_hours + shift.duration.total_seconds() / 3600
    penalty += 0.02 * projected_hours

    return penalty


def _build_result(
    assignments: Dict[str, List[Shift]],
    shifts: Sequence[Shift],
    *,
    score: float,
    iterations: int,
) -> OptimizationResult:
    assignments_map: Dict[str, str] = {}
    per_professional: Dict[str, Dict[str, object]] = {}
    shift_lookup: Dict[str, Shift] = {shift.identifier: shift for shift in shifts}

    for professional, prof_shifts in assignments.items():
        prof_shifts_sorted = sorted(prof_shifts, key=lambda s: s.start)
        per_professional[professional] = {
            "total_shifts": len(prof_shifts_sorted),
            "total_hours": sum(s.duration.total_seconds() / 3600 for s in prof_shifts_sorted),
            "dates": [s.date.isoformat() for s in prof_shifts_sorted],
            "streak_max": _longest_consecutive_streak([s.date for s in prof_shifts_sorted]),
        }
        for shift in prof_shifts_sorted:
            assignments_map[shift.identifier] = professional

    assigned_ids = set(assignments_map)
    unassigned = [shift for shift in shifts if shift.identifier not in assigned_ids]

    return OptimizationResult(
        assignments=assignments_map,
        unassigned=unassigned,
        per_professional=per_professional,
        score=score,
        iterations=iterations,
        shifts=shift_lookup,
    )


def optimize_schedule(
    config: Dict[str, object],
    *,
    iterations: int = 400,
    seed: Optional[int] = None,
    preference_reward: float = 0.8,
    undesired_penalty: float = 1.5,
    balance_weight: float = 1.2,
) -> OptimizationResult:
    """Executa otimização heurística da agenda.

    Args:
        config: Configuração carregada via :func:`load_configuration`.
        iterations: Número de tentativas com ordens distintas para busca da
            melhor solução.
        seed: Semente para controlar a aleatoriedade.
        preference_reward: Redução de penalidade ao atender preferências.
        undesired_penalty: Penalidade aplicada ao escalar em datas indesejadas.
        balance_weight: Peso utilizado para balancear quantidade de plantões.
    """

    raw_shifts = config.get("shifts", [])
    raw_professionals = config.get("professionals", [])
    if not isinstance(raw_shifts, Iterable) or not isinstance(raw_professionals, Iterable):
        raise ValueError("Configuração inválida: campos 'shifts' e 'professionals' são obrigatórios.")

    shifts = _prepare_shifts(list(raw_shifts))
    professionals = _prepare_professionals(list(raw_professionals))

    if not shifts:
        raise ValueError("Nenhum plantão informado na configuração.")
    if not professionals:
        raise ValueError("Nenhum profissional informado na configuração.")

    min_rest_hours = float(config.get("min_rest_hours", 12))
    max_consecutive_days = config.get("max_consecutive_days")
    if max_consecutive_days is not None:
        max_consecutive_days = int(max_consecutive_days)

    fairness_target = config.get("target_shifts_per_person")
    if fairness_target is None:
        fairness_target = len(shifts) / len(professionals)
    else:
        fairness_target = float(fairness_target)

    shifts_sorted = sorted(shifts, key=lambda s: (s.start, s.identifier))
    best_score = math.inf
    best_assignments: Dict[str, List[Shift]] = {}

    rng = random.Random(seed)

    for iteration in range(iterations):
        rng.shuffle(shifts_sorted)
        assignments: Dict[str, List[Shift]] = {prof.name: [] for prof in professionals}
        score = 0.0
        unassigned_penalty = 0.0

        for shift in shifts_sorted:
            candidates: List[Tuple[float, Professional]] = []
            for professional in professionals:
                if not _can_assign(
                    professional,
                    shift,
                    assignments,
                    global_rest_hours=min_rest_hours,
                    max_consecutive_days=max_consecutive_days,
                ):
                    continue
                candidate_penalty = _evaluate_candidate(
                    professional,
                    shift,
                    assignments,
                    fairness_target=fairness_target,
                    preference_reward=preference_reward,
                    undesired_penalty=undesired_penalty,
                    balance_weight=balance_weight,
                )
                # pequeno ruído para diversificar empates
                candidate_penalty += rng.random() * 0.01
                candidates.append((candidate_penalty, professional))

            if not candidates:
                unassigned_penalty += 5.0
                continue

            chosen_penalty, chosen_professional = min(candidates, key=lambda item: item[0])
            assignments[chosen_professional.name].append(shift)
            score += chosen_penalty

        # penaliza desvios globais de equilíbrio
        fairness_cost = 0.0
        for professional in professionals:
            allocated = len(assignments[professional.name])
            fairness_cost += (allocated - fairness_target) ** 2
        total_score = score + fairness_cost + unassigned_penalty

        if total_score < best_score:
            best_score = total_score
            best_assignments = {
                prof: list(shifts_assigned)
                for prof, shifts_assigned in assignments.items()
            }

    # refina ordenando cronologicamente para retorno
    for prof, prof_shifts in best_assignments.items():
        best_assignments[prof] = sorted(prof_shifts, key=lambda s: s.start)

    return _build_result(best_assignments, shifts, score=best_score, iterations=iterations)


def _format_table(result: OptimizationResult) -> str:
    from textwrap import indent

    lines = ["Resumo da escala otimizada:"]
    for professional, info in sorted(result.per_professional.items()):
        lines.append(
            f"- {professional}: {info['total_shifts']} plantões, "
            f"{info['total_hours']:.1f} h, sequência máxima {info['streak_max']} dias"
        )
        if info["dates"]:
            dates = ", ".join(info["dates"])
            lines.append(indent(f"Datas: {dates}", "  "))

    if result.unassigned:
        unassigned_ids = ", ".join(shift.identifier for shift in result.unassigned)
        lines.append(f"Plantões não preenchidos: {unassigned_ids}")
    else:
        lines.append("Todos os plantões foram preenchidos.")

    lines.append(f"Pontuação final: {result.score:.2f} (quanto menor, melhor)")
    return "\n".join(lines)


def main(argv: Optional[Sequence[str]] = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Otimiza agenda de plantão a partir de um arquivo de configuração.")
    parser.add_argument("config", type=Path, help="Arquivo JSON ou YAML com dados da escala.")
    parser.add_argument("--iterations", type=int, default=400, help="Número de iterações da busca (padrão: 400).")
    parser.add_argument("--seed", type=int, default=None, help="Semente opcional para reprodutibilidade.")
    parser.add_argument("--dump-json", type=Path, help="Arquivo para salvar o resultado em JSON.")
    parser.add_argument("--icloud-user", help="Apple ID (e-mail) para integração via CalDAV.")
    parser.add_argument("--icloud-app-password", help="Senha específica de app gerada no iCloud.")
    parser.add_argument("--icloud-calendar", help="Nome do calendário destino no iCloud.")
    parser.add_argument(
        "--icloud-server",
        help="URL CalDAV do iCloud (padrão: https://caldav.icloud.com/).",
    )
    parser.add_argument(
        "--icloud-timezone",
        help="Timezone IANA (ex: America/Sao_Paulo) utilizado ao criar eventos.",
    )
    parser.add_argument(
        "--icloud-keep-existing",
        action="store_true",
        help="Não remover eventos anteriores com o mesmo ID de plantão.",
    )

    args = parser.parse_args(argv)

    config = load_configuration(args.config)
    result = optimize_schedule(config, iterations=args.iterations, seed=args.seed)

    print(_format_table(result))

    if args.dump_json:
        args.dump_json.write_text(
            json.dumps(result.to_dict(), indent=2, ensure_ascii=False), encoding="utf-8"
        )

    icloud_user = args.icloud_user or os.getenv("PLANTAO_ICLOUD_USER")
    icloud_password = args.icloud_app_password or os.getenv("PLANTAO_ICLOUD_APP_PASSWORD")
    icloud_calendar = args.icloud_calendar or os.getenv("PLANTAO_ICLOUD_CALENDAR")

    if any([icloud_user, icloud_password, icloud_calendar]):
        if not (icloud_user and icloud_password and icloud_calendar):
            print(
                "Para exportar ao iCloud informe usuário, senha específica de app e nome do calendário.",
                file=sys.stderr,
            )
            return 2

        icloud_server = args.icloud_server or os.getenv("PLANTAO_ICLOUD_SERVER", "https://caldav.icloud.com/")
        timezone_name = args.icloud_timezone or os.getenv("PLANTAO_ICLOUD_TIMEZONE")
        clear_existing = not args.icloud_keep_existing

        try:
            from .icloud import ICloudConfig, ICloudIntegrationError, connect, export_result

            config_obj = ICloudConfig(
                username=icloud_user,
                app_password=icloud_password,
                calendar=icloud_calendar,
                server_url=icloud_server,
            )
            calendar = connect(config_obj)
            created = export_result(
                result,
                calendar,
                timezone_name=timezone_name,
                clear_existing=clear_existing,
            )
            print(f"Eventos enviados ao iCloud: {created}")
        except ICloudIntegrationError as exc:
            print(f"Falha ao exportar para o iCloud: {exc}", file=sys.stderr)
            return 2

    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
