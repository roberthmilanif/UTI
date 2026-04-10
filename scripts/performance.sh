#!/bin/bash
# =============================================================================
# Steam Deck - Otimização de Performance
# CPU governor, GPU, swap/zram, TDP e scheduler
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

# ----------------------------------------------------------------------------
# CPU Governor
# ----------------------------------------------------------------------------
set_cpu_governor() {
    local governor="${1:-schedutil}"
    info "Configurando CPU governor para: $governor"

    if [[ ! -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        warn "cpufreq não disponível. Pulando."
        return
    fi

    local cores
    cores=$(nproc)
    local applied=0

    for ((i=0; i<cores; i++)); do
        local gov_path="/sys/devices/system/cpu/cpu${i}/cpufreq/scaling_governor"
        if [[ -w "$gov_path" ]]; then
            echo "$governor" > "$gov_path"
            ((applied++))
        fi
    done

    log "Governor '$governor' aplicado em $applied núcleos."
}

# ----------------------------------------------------------------------------
# CPU Boost
# ----------------------------------------------------------------------------
set_cpu_boost() {
    local state="${1:-1}"  # 1 = ativado, 0 = desativado
    local boost_path="/sys/devices/system/cpu/cpufreq/boost"

    if [[ -w "$boost_path" ]]; then
        echo "$state" > "$boost_path"
        local label; [[ "$state" == "1" ]] && label="ativado" || label="desativado"
        log "CPU Boost $label."
    else
        warn "CPU Boost não disponível neste hardware."
    fi
}

# ----------------------------------------------------------------------------
# Swappiness e Swap
# ----------------------------------------------------------------------------
optimize_swap() {
    info "Otimizando configurações de swap..."

    # Reduz swappiness para priorizar RAM
    sysctl -w vm.swappiness=10 > /dev/null
    sysctl -w vm.vfs_cache_pressure=50 > /dev/null

    # Torna persistente
    local sysctl_conf="/etc/sysctl.d/99-steamdeck-perf.conf"
    cat > "$sysctl_conf" <<EOF
# Steam Deck - Otimizações de memória
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=15
vm.dirty_background_ratio=5
EOF
    log "Swappiness definido para 10 (padrão: 60)."
    log "Configuração salva em $sysctl_conf"
}

# ----------------------------------------------------------------------------
# zRAM
# ----------------------------------------------------------------------------
setup_zram() {
    info "Configurando zRAM para compressão de swap em memória..."

    if ! modprobe zram 2>/dev/null; then
        warn "Módulo zram não disponível. Pulando."
        return
    fi

    local zram_dev="/dev/zram0"
    if [[ ! -b "$zram_dev" ]]; then
        warn "Dispositivo $zram_dev não encontrado após modprobe."
        return
    fi

    # Usa metade da RAM disponível para zRAM
    local total_ram
    total_ram=$(awk '/MemTotal/{print $2}' /proc/meminfo)
    local zram_size=$(( total_ram * 1024 / 2 ))  # metade em bytes

    # Reset e configura
    swapoff "$zram_dev" 2>/dev/null || true
    echo 1 > /sys/block/zram0/reset 2>/dev/null || true

    echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || \
        echo lzo > /sys/block/zram0/comp_algorithm 2>/dev/null || true

    echo "$zram_size" > /sys/block/zram0/disksize
    mkswap "$zram_dev" > /dev/null
    swapon -p 100 "$zram_dev"

    log "zRAM configurado: $(( zram_size / 1024 / 1024 )) MB com compressão lz4."
}

# ----------------------------------------------------------------------------
# I/O Scheduler
# ----------------------------------------------------------------------------
set_io_scheduler() {
    local scheduler="${1:-mq-deadline}"
    info "Definindo I/O scheduler para: $scheduler"

    local applied=0
    for dev in /sys/block/*/queue/scheduler; do
        if [[ -w "$dev" ]]; then
            echo "$scheduler" > "$dev" 2>/dev/null && ((applied++)) || true
        fi
    done

    log "I/O scheduler '$scheduler' aplicado em $applied dispositivos."
}

# ----------------------------------------------------------------------------
# Transparent Huge Pages
# ----------------------------------------------------------------------------
set_thp() {
    local thp_path="/sys/kernel/mm/transparent_hugepage/enabled"
    if [[ -w "$thp_path" ]]; then
        echo "madvise" > "$thp_path"
        log "Transparent Huge Pages definido para 'madvise' (otimizado para jogos)."
    fi
}

# ----------------------------------------------------------------------------
# Prioridade de processos de jogo
# ----------------------------------------------------------------------------
set_game_nice() {
    info "Configurando limites de prioridade para jogos..."

    local limits_conf="/etc/security/limits.d/99-steamdeck-game.conf"
    cat > "$limits_conf" <<EOF
# Steam Deck - Prioridade de processos para jogos
*       soft    nice    -10
*       hard    nice    -15
EOF
    log "Limites de nice configurados para jogos."
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
main() {
    echo ""
    echo "============================================="
    echo "  Steam Deck - Otimização de Performance"
    echo "============================================="
    echo ""

    require_root

    set_cpu_governor "schedutil"
    set_cpu_boost 1
    optimize_swap
    setup_zram
    set_io_scheduler "mq-deadline"
    set_thp
    set_game_nice

    echo ""
    log "Otimização de performance concluída!"
    warn "Reinicie o Steam Deck para garantir que todas as configurações foram aplicadas."
}

main "$@"
