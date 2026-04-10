#!/bin/bash
# =============================================================================
# Steam Deck - Otimização de Rede e Downloads
# TCP tuning, BBR, buffers, DNS cache e Steam download
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

SYSCTL_NET_CONF="/etc/sysctl.d/99-steamdeck-net.conf"

# ----------------------------------------------------------------------------
# TCP Buffer Tuning
# Aumenta buffers para maior throughput em downloads grandes
# ----------------------------------------------------------------------------
tune_tcp_buffers() {
    info "Configurando buffers TCP para alta velocidade de download..."

    sysctl -w net.core.rmem_max=134217728        > /dev/null  # 128MB
    sysctl -w net.core.wmem_max=134217728        > /dev/null
    sysctl -w net.core.rmem_default=16777216     > /dev/null  # 16MB
    sysctl -w net.core.wmem_default=16777216     > /dev/null
    sysctl -w net.core.optmem_max=65536          > /dev/null
    sysctl -w net.core.netdev_max_backlog=5000   > /dev/null

    sysctl -w "net.ipv4.tcp_rmem=4096 87380 134217728" > /dev/null
    sysctl -w "net.ipv4.tcp_wmem=4096 65536 134217728" > /dev/null

    log "Buffers TCP configurados para 128MB máximo."
}

# ----------------------------------------------------------------------------
# TCP BBR Congestion Control
# Algoritmo moderno do Google — melhor throughput e menor latência
# ----------------------------------------------------------------------------
enable_bbr() {
    info "Habilitando TCP BBR (congestion control)..."

    # Verifica se BBR está disponível
    if ! modprobe tcp_bbr 2>/dev/null; then
        warn "Módulo tcp_bbr não disponível. Usando CUBIC como fallback."
        sysctl -w net.ipv4.tcp_congestion_control=cubic > /dev/null
        return
    fi

    local available
    available=$(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null)

    if echo "$available" | grep -q "bbr"; then
        sysctl -w net.ipv4.tcp_congestion_control=bbr > /dev/null
        sysctl -w net.core.default_qdisc=fq             > /dev/null
        log "TCP BBR ativado com fq qdisc."
    else
        warn "BBR não disponível no kernel atual. Mantendo padrão."
    fi
}

# ----------------------------------------------------------------------------
# TCP Fast Open
# Reduz latência em conexões TCP repetidas
# ----------------------------------------------------------------------------
enable_tcp_fastopen() {
    info "Habilitando TCP Fast Open..."
    # 3 = ativado para cliente e servidor
    sysctl -w net.ipv4.tcp_fastopen=3 > /dev/null
    log "TCP Fast Open ativado (cliente + servidor)."
}

# ----------------------------------------------------------------------------
# Otimizações gerais TCP
# ----------------------------------------------------------------------------
tune_tcp_misc() {
    info "Aplicando otimizações gerais de TCP..."

    # Aumenta backlog de conexões
    sysctl -w net.core.somaxconn=65535            > /dev/null
    sysctl -w net.ipv4.tcp_max_syn_backlog=65535  > /dev/null

    # Reutilização de sockets em TIME_WAIT
    sysctl -w net.ipv4.tcp_tw_reuse=1             > /dev/null

    # Keep-alive para conexões Steam (mantém sessão ativa)
    sysctl -w net.ipv4.tcp_keepalive_time=60      > /dev/null
    sysctl -w net.ipv4.tcp_keepalive_intvl=10     > /dev/null
    sysctl -w net.ipv4.tcp_keepalive_probes=6     > /dev/null

    # Janela de TCP automática
    sysctl -w net.ipv4.tcp_window_scaling=1       > /dev/null
    sysctl -w net.ipv4.tcp_timestamps=1           > /dev/null
    sysctl -w net.ipv4.tcp_sack=1                 > /dev/null

    # Evita fragmentação de pacotes
    sysctl -w net.ipv4.tcp_mtu_probing=1          > /dev/null

    log "Otimizações gerais TCP aplicadas."
}

# ----------------------------------------------------------------------------
# Persistir configurações no sysctl.d
# ----------------------------------------------------------------------------
persist_sysctl() {
    info "Salvando configurações de rede permanentemente..."

    cat > "$SYSCTL_NET_CONF" <<EOF
# =============================================================
# Steam Deck - Otimizações de Rede
# Gerado por: scripts/network.sh
# =============================================================

# Buffers TCP grandes para downloads rápidos
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.core.optmem_max = 65536
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# TCP BBR + Fair Queue
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# TCP Fast Open
net.ipv4.tcp_fastopen = 3

# Backlog e conexões simultâneas
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# Reutilização de sockets
net.ipv4.tcp_tw_reuse = 1

# Keep-alive (mantém sessão Steam ativa)
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 6

# Janela TCP e features
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_mtu_probing = 1
EOF

    log "Configurações salvas em: $SYSCTL_NET_CONF"
    log "Serão aplicadas automaticamente na próxima inicialização."
}

# ----------------------------------------------------------------------------
# Otimizar DNS com systemd-resolved
# ----------------------------------------------------------------------------
optimize_dns() {
    info "Otimizando DNS com systemd-resolved..."

    if ! systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        warn "systemd-resolved não está ativo. Pulando otimização de DNS."
        return
    fi

    local resolved_conf="/etc/systemd/resolved.conf.d/99-steamdeck-dns.conf"
    mkdir -p "$(dirname "$resolved_conf")"

    cat > "$resolved_conf" <<EOF
[Resolve]
# DNS primário: Cloudflare (1.1.1.1) + Google (8.8.8.8)
DNS=1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4
FallbackDNS=9.9.9.9 149.112.112.112

# DNS sobre TLS para privacidade
DNSOverTLS=opportunistic

# Cache DNS agressivo
Cache=yes

# DNSSEC
DNSSEC=allow-downgrade

# Aumenta timeout de cache
CacheFromLocalhost=yes
EOF

    systemctl restart systemd-resolved 2>/dev/null && \
        log "DNS configurado: Cloudflare 1.1.1.1 + Google 8.8.8.8 com cache." || \
        warn "Não foi possível reiniciar systemd-resolved."
}

# ----------------------------------------------------------------------------
# Otimizar NIC (Network Interface Card)
# ----------------------------------------------------------------------------
tune_nic() {
    info "Otimizando interface de rede..."

    local iface=""

    # Detecta interface WiFi ativa
    if command -v ip &>/dev/null; then
        iface=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
    fi

    if [[ -z "$iface" ]]; then
        warn "Interface de rede ativa não detectada."
        return
    fi

    info "Interface detectada: $iface"

    # Aumenta ring buffer se ethtool disponível
    if command -v ethtool &>/dev/null; then
        ethtool -G "$iface" rx 4096 tx 4096 2>/dev/null && \
            log "Ring buffer de $iface aumentado para 4096." || \
            warn "Não foi possível ajustar ring buffer de $iface (normal em WiFi)."

        # Generic Receive Offload
        ethtool -K "$iface" gro on 2>/dev/null && \
            log "GRO ativado em $iface." || true

        # TCP Segmentation Offload
        ethtool -K "$iface" tso on 2>/dev/null && \
            log "TSO ativado em $iface." || true
    else
        warn "ethtool não encontrado. Pulando otimização de NIC."
    fi
}

# ----------------------------------------------------------------------------
# Configurar Steam para downloads mais rápidos
# ----------------------------------------------------------------------------
optimize_steam_downloads() {
    info "Otimizando configurações de download do Steam..."

    local steam_cfg="${HOME}/.steam/steam/steam.cfg"
    mkdir -p "$(dirname "$steam_cfg")"

    # Cria ou atualiza configuração
    if [[ ! -f "$steam_cfg" ]]; then
        cat > "$steam_cfg" <<EOF
@sSteamCmdForcePlatformType linux
BootStrapperInhibitAll=enable
EOF
    fi

    # Configuração de download no Steam (arquivo de usuário)
    local user_cfg="${HOME}/.local/share/Steam/config/config.vdf"
    if [[ -f "$user_cfg" ]]; then
        info "Para velocidade máxima de download no Steam:"
        info "  Steam > Configurações > Downloads"
        info "  - Região de download: escolha a mais próxima"
        info "  - Limite de velocidade: desativado"
        info "  - Permitir downloads durante gameplay: conforme preferência"
    fi

    log "Dica: no Steam, vá em Configurações > Downloads e selecione"
    log "      a região de servidor mais próxima da sua localização."
}

# ----------------------------------------------------------------------------
# Teste de velocidade básico
# ----------------------------------------------------------------------------
run_speed_test() {
    info "Testando conectividade e latência..."

    local hosts=("1.1.1.1" "8.8.8.8" "steamcommunity.com")

    for host in "${hosts[@]}"; do
        local latency
        latency=$(ping -c 3 -W 2 "$host" 2>/dev/null | \
                  awk -F'/' '/rtt/{print $5"ms"}' || echo "timeout")
        echo "  Ping $host: $latency"
    done
    echo ""
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
main() {
    echo ""
    echo "============================================="
    echo "  Steam Deck - Otimização de Rede"
    echo "============================================="
    echo ""

    require_root

    run_speed_test
    tune_tcp_buffers
    enable_bbr
    enable_tcp_fastopen
    tune_tcp_misc
    persist_sysctl
    optimize_dns
    tune_nic
    optimize_steam_downloads

    echo ""
    info "Latência após otimizações:"
    run_speed_test

    log "Otimização de rede concluída!"
    warn "Reinicie o Steam Deck para garantir que todas as configurações foram aplicadas."
}

main "$@"
