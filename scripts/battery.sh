#!/bin/bash
# =============================================================================
# Steam Deck - Otimização de Bateria / Energia
# Perfis de energia, TDP, brilho, WiFi e suspend
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
err()  { echo -e "${RED}[ERRO]${NC} $1"; }

require_root() {
    if [[ $EUID -ne 0 ]]; then
        err "Este script precisa ser executado como root (sudo)."
        exit 1
    fi
}

# Steam Deck APU: AMD Van Gogh (Zen 2 + RDNA 2)
# TDP range: 3W – 15W
TDP_MIN_WATT=3000      # 3W  em mW
TDP_BAL_WATT=8000      # 8W  em mW
TDP_MAX_WATT=15000     # 15W em mW

# ----------------------------------------------------------------------------
# CPU Governor
# ----------------------------------------------------------------------------
set_cpu_governor() {
    local governor="$1"
    local cores
    cores=$(nproc)

    for ((i=0; i<cores; i++)); do
        local path="/sys/devices/system/cpu/cpu${i}/cpufreq/scaling_governor"
        if [[ -w "$path" ]]; then
            echo "$governor" > "$path"
        fi
    done
    log "CPU governor: $governor"
}

# ----------------------------------------------------------------------------
# TDP via ryzenadj
# ----------------------------------------------------------------------------
set_tdp() {
    local tdp_mw="$1"
    local tdp_w=$(( tdp_mw / 1000 ))

    if command -v ryzenadj &>/dev/null; then
        # stapm-limit, fast-limit, slow-limit em mW
        ryzenadj \
            --stapm-limit="$tdp_mw" \
            --fast-limit="$tdp_mw" \
            --slow-limit="$tdp_mw" \
            --tctl-temp=90 \
            2>/dev/null && log "TDP definido para ${tdp_w}W via ryzenadj." \
                        || warn "ryzenadj falhou ao definir TDP."
    else
        warn "ryzenadj não encontrado. Instale para controle preciso de TDP."
        warn "  Alternativa: use o menu Quick Access do Steam Deck (botão '...')."
    fi
}

# ----------------------------------------------------------------------------
# Brilho da tela
# ----------------------------------------------------------------------------
set_brightness() {
    local percent="$1"   # 0-100
    local backlight_dir
    backlight_dir=$(ls /sys/class/backlight/ 2>/dev/null | head -1)

    if [[ -z "$backlight_dir" ]]; then
        warn "Controle de brilho não encontrado via sysfs."
        return
    fi

    local max_bright
    max_bright=$(cat "/sys/class/backlight/${backlight_dir}/max_brightness" 2>/dev/null || echo 100)
    local target=$(( max_bright * percent / 100 ))

    echo "$target" > "/sys/class/backlight/${backlight_dir}/brightness" 2>/dev/null && \
        log "Brilho definido para ${percent}% ($target/$max_bright)." || \
        warn "Não foi possível definir o brilho."
}

# ----------------------------------------------------------------------------
# WiFi Power Management
# ----------------------------------------------------------------------------
set_wifi_power() {
    local mode="$1"  # on | off

    if command -v iwconfig &>/dev/null; then
        local iface
        iface=$(iwconfig 2>/dev/null | awk '/IEEE/{print $1}' | head -1)
        if [[ -n "$iface" ]]; then
            iwconfig "$iface" power "$mode" 2>/dev/null && \
                log "WiFi power management: $mode ($iface)." || \
                warn "Não foi possível configurar WiFi power management."
        fi
    elif command -v iw &>/dev/null; then
        local iface
        iface=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
        if [[ -n "$iface" ]]; then
            iw dev "$iface" set power_save "$mode" 2>/dev/null && \
                log "WiFi power save: $mode ($iface)." || \
                warn "Não foi possível configurar WiFi power save."
        fi
    else
        warn "iwconfig/iw não encontrado. Pulando configuração de WiFi."
    fi
}

# ----------------------------------------------------------------------------
# Auto-suspend via systemd logind
# ----------------------------------------------------------------------------
set_autosuspend() {
    local idle_sec="$1"   # segundos até suspend (0 = desativado)

    local logind_conf="/etc/systemd/logind.conf.d/99-steamdeck-sleep.conf"
    mkdir -p "$(dirname "$logind_conf")"

    if [[ "$idle_sec" -eq 0 ]]; then
        cat > "$logind_conf" <<EOF
[Login]
IdleAction=ignore
IdleActionSec=0
EOF
        log "Auto-suspend desativado."
    else
        cat > "$logind_conf" <<EOF
[Login]
IdleAction=suspend
IdleActionSec=${idle_sec}s
EOF
        log "Auto-suspend configurado para ${idle_sec}s de inatividade."
    fi

    systemctl restart systemd-logind 2>/dev/null || true
}

# ----------------------------------------------------------------------------
# Desativar serviços desnecessários em modo bateria
# ----------------------------------------------------------------------------
disable_power_hungry_services() {
    info "Desativando serviços que consomem energia desnecessariamente..."

    local services=(
        "bluetooth"        # Desativa BT se não estiver em uso
        "cups"             # Impressão — desnecessário no Steam Deck
        "avahi-daemon"     # mDNS/Bonjour — raramente necessário
    )

    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            systemctl stop "$svc" 2>/dev/null && \
                log "Serviço parado: $svc" || \
                warn "Não foi possível parar: $svc"
        fi
    done
}

# ----------------------------------------------------------------------------
# Configurar kernel power settings
# ----------------------------------------------------------------------------
set_kernel_power() {
    info "Configurando parâmetros de energia do kernel..."

    # Runtime PM para dispositivos PCI/USB
    for dev in /sys/bus/pci/devices/*/power/control; do
        [[ -w "$dev" ]] && echo "auto" > "$dev" 2>/dev/null || true
    done

    for dev in /sys/bus/usb/devices/*/power/control; do
        [[ -w "$dev" ]] && echo "auto" > "$dev" 2>/dev/null || true
    done

    # CPU energy preference
    for ep in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
        [[ -w "$ep" ]] && echo "balance_power" > "$ep" 2>/dev/null || true
    done

    log "Runtime PM configurado para dispositivos PCI/USB."
    log "CPU energy preference: balance_power."
}

# ----------------------------------------------------------------------------
# Criar serviço systemd para persistir configurações de bateria
# ----------------------------------------------------------------------------
create_battery_service() {
    local profile="$1"
    local service_file="/etc/systemd/system/steamdeck-battery-${profile}.service"

    cat > "$service_file" <<EOF
[Unit]
Description=Steam Deck Battery Profile: $profile
After=multi-user.target

[Service]
Type=oneshot
ExecStart=$(realpath "$0") --profile $profile
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload 2>/dev/null || true
    log "Serviço criado: steamdeck-battery-${profile}.service"
    info "Para ativar na inicialização: sudo systemctl enable steamdeck-battery-${profile}"
}

# ----------------------------------------------------------------------------
# Perfis
# ----------------------------------------------------------------------------
apply_profile_economy() {
    echo ""
    info "Aplicando perfil: ECONOMIA DE BATERIA"
    echo "  - CPU governor: powersave"
    echo "  - TDP: ${TDP_MIN_WATT}mW ($(( TDP_MIN_WATT/1000 ))W)"
    echo "  - Brilho: 30%"
    echo "  - WiFi power save: on"
    echo "  - Auto-suspend: 5 minutos"
    echo ""

    set_cpu_governor "powersave"
    set_tdp "$TDP_MIN_WATT"
    set_brightness 30
    set_wifi_power "on"
    set_autosuspend 300
    set_kernel_power
    disable_power_hungry_services
}

apply_profile_balanced() {
    echo ""
    info "Aplicando perfil: BALANCEADO"
    echo "  - CPU governor: schedutil"
    echo "  - TDP: ${TDP_BAL_WATT}mW ($(( TDP_BAL_WATT/1000 ))W)"
    echo "  - Brilho: 60%"
    echo "  - WiFi power save: off"
    echo "  - Auto-suspend: 15 minutos"
    echo ""

    set_cpu_governor "schedutil"
    set_tdp "$TDP_BAL_WATT"
    set_brightness 60
    set_wifi_power "off"
    set_autosuspend 900
    set_kernel_power
}

apply_profile_performance() {
    echo ""
    info "Aplicando perfil: PERFORMANCE MÁXIMA"
    echo "  - CPU governor: performance"
    echo "  - TDP: ${TDP_MAX_WATT}mW ($(( TDP_MAX_WATT/1000 ))W)"
    echo "  - Brilho: 100%"
    echo "  - WiFi power save: off"
    echo "  - Auto-suspend: desativado"
    echo ""

    set_cpu_governor "performance"
    set_tdp "$TDP_MAX_WATT"
    set_brightness 100
    set_wifi_power "off"
    set_autosuspend 0
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
main() {
    echo ""
    echo "============================================="
    echo "  Steam Deck - Otimização de Bateria"
    echo "============================================="
    echo ""

    require_root

    # Parse argumento de perfil
    local profile="${1:-}"

    if [[ -z "$profile" ]]; then
        echo "Escolha um perfil de energia:"
        echo "  1) Economia de bateria  (máxima duração)"
        echo "  2) Balanceado           (padrão recomendado)"
        echo "  3) Performance máxima   (jogabilidade intensa)"
        echo ""
        read -rp "Opção [1-3]: " choice
        case "$choice" in
            1) profile="economy" ;;
            2) profile="balanced" ;;
            3) profile="performance" ;;
            *) err "Opção inválida."; exit 1 ;;
        esac
    fi

    case "$profile" in
        --profile\ economy|economy)    apply_profile_economy ;;
        --profile\ balanced|balanced)  apply_profile_balanced ;;
        --profile\ performance|performance) apply_profile_performance ;;
        *)
            err "Perfil desconhecido: $profile"
            echo "Use: economy | balanced | performance"
            exit 1
            ;;
    esac

    echo ""
    read -rp "Criar serviço para aplicar este perfil na inicialização? [s/N] " persist
    if [[ "$persist" =~ ^[sS]$ ]]; then
        create_battery_service "$profile"
    fi

    echo ""
    log "Perfil de energia '$profile' aplicado com sucesso!"
}

main "$@"
