#!/bin/bash
# =============================================================================
# Steam Deck - Suite de Otimização
# Script principal que coordena todos os módulos de otimização
#
# Uso:
#   sudo ./optimize.sh                    # menu interativo
#   sudo ./optimize.sh --all              # tudo de uma vez
#   sudo ./optimize.sh --performance      # só performance
#   sudo ./optimize.sh --storage          # só armazenamento (sem root)
#   sudo ./optimize.sh --battery economy  # bateria com perfil economy
#   sudo ./optimize.sh --network          # só rede
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
err()  { echo -e "${RED}[ERRO]${NC} $1"; }

# ----------------------------------------------------------------------------
# Verificações iniciais
# ----------------------------------------------------------------------------
check_scripts() {
    local missing=0
    for script in performance storage battery network; do
        if [[ ! -f "${SCRIPTS_DIR}/${script}.sh" ]]; then
            err "Script não encontrado: ${SCRIPTS_DIR}/${script}.sh"
            ((missing++))
        fi
    done
    if [[ $missing -gt 0 ]]; then
        err "Execute este script a partir do diretório raiz do repositório."
        exit 1
    fi
}

check_steam_deck() {
    # Verifica se está rodando em um Steam Deck (ou ambiente compatível)
    if [[ -f /sys/class/dmi/id/product_name ]]; then
        local product
        product=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
        if [[ "$product" == *"Steam Deck"* ]] || [[ "$product" == *"Jupiter"* ]]; then
            log "Steam Deck detectado: $product"
            return 0
        fi
    fi
    warn "Dispositivo não identificado como Steam Deck."
    warn "Os scripts foram otimizados para o Steam Deck mas podem funcionar"
    warn "em outros dispositivos Linux com AMD APU."
    echo ""
}

# ----------------------------------------------------------------------------
# Banner
# ----------------------------------------------------------------------------
show_banner() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║      STEAM DECK - SUITE DE OTIMIZAÇÃO    ║"
    echo "  ║         github.com/roberthmilanif/UTI     ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ----------------------------------------------------------------------------
# Menu interativo
# ----------------------------------------------------------------------------
show_menu() {
    echo -e "${BOLD}Selecione o que deseja otimizar:${NC}"
    echo ""
    echo "  1) Performance    - CPU, swap, zRAM, I/O scheduler"
    echo "  2) Armazenamento  - Limpar caches, shader cache, SD card"
    echo "  3) Bateria        - Perfis de energia, TDP, brilho"
    echo "  4) Rede           - TCP, BBR, DNS, buffers de download"
    echo "  5) Tudo           - Executa todas as otimizações"
    echo "  0) Sair"
    echo ""
    read -rp "Opção: " choice
    echo ""

    case "$choice" in
        1) run_module "performance" ;;
        2) run_module "storage" ;;
        3) run_module "battery" ;;
        4) run_module "network" ;;
        5) run_all ;;
        0) info "Saindo."; exit 0 ;;
        *) err "Opção inválida: $choice"; show_menu ;;
    esac
}

# ----------------------------------------------------------------------------
# Executar um módulo
# ----------------------------------------------------------------------------
run_module() {
    local module="$1"
    shift || true
    local args=("$@")

    local script="${SCRIPTS_DIR}/${module}.sh"
    chmod +x "$script"

    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Storage não precisa de root para limpeza básica
    if [[ "$module" == "storage" ]]; then
        bash "$script" "${args[@]}"
    else
        if [[ $EUID -ne 0 ]]; then
            warn "Módulo '$module' requer privilégios root."
            if command -v sudo &>/dev/null; then
                sudo bash "$script" "${args[@]}"
            else
                err "sudo não encontrado. Execute como root."
                return 1
            fi
        else
            bash "$script" "${args[@]}"
        fi
    fi

    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ----------------------------------------------------------------------------
# Executar tudo
# ----------------------------------------------------------------------------
run_all() {
    info "Executando todas as otimizações..."
    echo ""

    local modules=("performance" "storage" "battery" "network")
    local failed=()

    for module in "${modules[@]}"; do
        if ! run_module "$module"; then
            failed+=("$module")
        fi
        echo ""
    done

    echo ""
    echo -e "${BOLD}════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  RESUMO${NC}"
    echo -e "${BOLD}════════════════════════════════════════════${NC}"

    for module in "${modules[@]}"; do
        if [[ " ${failed[*]} " =~ " ${module} " ]]; then
            echo -e "  ${RED}✗${NC} $module"
        else
            echo -e "  ${GREEN}✓${NC} $module"
        fi
    done

    echo ""
    if [[ ${#failed[@]} -eq 0 ]]; then
        log "Todas as otimizações foram aplicadas com sucesso!"
    else
        warn "${#failed[@]} módulo(s) com falha: ${failed[*]}"
    fi
    warn "Reinicie o Steam Deck para garantir que todas as configurações foram aplicadas."
}

# ----------------------------------------------------------------------------
# Ajuda
# ----------------------------------------------------------------------------
show_help() {
    echo ""
    echo "Uso: $0 [OPÇÃO] [ARGS]"
    echo ""
    echo "Opções:"
    echo "  --all                  Executa todas as otimizações"
    echo "  --performance          Otimiza CPU, swap, zRAM e I/O"
    echo "  --storage              Limpa caches e gerencia armazenamento"
    echo "  --battery [perfil]     Configura energia (economy|balanced|performance)"
    echo "  --network              Otimiza TCP, DNS e downloads"
    echo "  --help, -h             Mostra esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  sudo $0 --all"
    echo "  sudo $0 --battery economy"
    echo "       $0 --storage"
    echo ""
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
main() {
    show_banner
    check_scripts
    check_steam_deck

    if [[ $# -eq 0 ]]; then
        show_menu
        return
    fi

    case "$1" in
        --all)         run_all ;;
        --performance) run_module "performance" "${@:2}" ;;
        --storage)     run_module "storage"     "${@:2}" ;;
        --battery)     run_module "battery"     "${@:2}" ;;
        --network)     run_module "network"     "${@:2}" ;;
        --help|-h)     show_help ;;
        *)
            err "Opção desconhecida: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
