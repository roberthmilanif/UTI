#!/bin/bash
# =============================================================================
# Steam Deck - Otimização de Armazenamento
# Limpeza de cache, shader cache, logs e symlinks para SD card
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
err()  { echo -e "${RED}[ERRO]${NC} $1"; }
size() { echo -e "${CYAN}[ESPAÇO]${NC} $1"; }

STEAM_HOME="${HOME}/.local/share/Steam"
STEAM_APPS="${STEAM_HOME}/steamapps"

# ----------------------------------------------------------------------------
# Calcula tamanho de um diretório de forma segura
# ----------------------------------------------------------------------------
dir_size() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        du -sh "$dir" 2>/dev/null | cut -f1
    else
        echo "0B"
    fi
}

# ----------------------------------------------------------------------------
# Limpar Shader Cache
# Recompilado automaticamente pelo Steam — seguro remover
# ----------------------------------------------------------------------------
clear_shader_cache() {
    info "Limpando shader cache do Steam..."

    local shader_dir="${STEAM_APPS}/shadercache"
    local compat_dir="${HOME}/.local/share/Steam/steamapps/compatdata"

    if [[ -d "$shader_dir" ]]; then
        local before
        before=$(dir_size "$shader_dir")
        find "$shader_dir" -type f -name "*.cache" -delete 2>/dev/null || true
        find "$shader_dir" -type f -name "*.log"   -delete 2>/dev/null || true
        log "Shader cache limpo (era: $before)."
    else
        warn "Diretório de shader cache não encontrado: $shader_dir"
    fi

    # Limpa shader cache do Proton/Wine
    local proton_shader="${HOME}/.cache/mesa_shader_cache"
    if [[ -d "$proton_shader" ]]; then
        local before
        before=$(dir_size "$proton_shader")
        rm -rf "${proton_shader:?}/"*  2>/dev/null || true
        log "Mesa shader cache limpo (era: $before)."
    fi
}

# ----------------------------------------------------------------------------
# Limpar Download Cache do Steam
# ----------------------------------------------------------------------------
clear_download_cache() {
    info "Limpando cache de downloads do Steam..."

    local pkg_dir="${STEAM_HOME}/package"
    if [[ -d "$pkg_dir" ]]; then
        local before
        before=$(dir_size "$pkg_dir")
        find "$pkg_dir" -type f \( -name "*.zip" -o -name "*.tar" -o -name "*.pkg" \) \
            -mtime +7 -delete 2>/dev/null || true
        log "Cache de downloads limpo (era: $before)."
    else
        warn "Diretório de packages não encontrado: $pkg_dir"
    fi

    # Temp files do Steam
    local tmp_steam="${STEAM_HOME}/logs"
    if [[ -d "$tmp_steam" ]]; then
        find "$tmp_steam" -type f -name "*.log" -mtime +14 -delete 2>/dev/null || true
        log "Logs antigos do Steam (>14 dias) removidos."
    fi
}

# ----------------------------------------------------------------------------
# Limpar Thumbnails e Cache do sistema
# ----------------------------------------------------------------------------
clear_thumbnails() {
    info "Limpando thumbnails e cache do sistema..."

    local thumb_dir="${HOME}/.local/share/thumbnails"
    if [[ -d "$thumb_dir" ]]; then
        local before
        before=$(dir_size "$thumb_dir")
        find "$thumb_dir" -type f -mtime +30 -delete 2>/dev/null || true
        # Remove diretórios vazios
        find "$thumb_dir" -type d -empty -delete 2>/dev/null || true
        log "Thumbnails antigos (>30 dias) removidos (era: $before)."
    fi

    # Cache geral do usuário
    local cache_dirs=(
        "${HOME}/.cache/fontconfig"
        "${HOME}/.cache/gstreamer-1.0"
        "${HOME}/.cache/ibus"
    )

    for dir in "${cache_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local before
            before=$(dir_size "$dir")
            rm -rf "${dir:?}" && log "Cache removido: $dir (era: $before)"
        fi
    done
}

# ----------------------------------------------------------------------------
# Limpar compatdata órfãos (jogos desinstalados)
# ----------------------------------------------------------------------------
clear_orphan_compatdata() {
    info "Verificando compatdata órfãos (prefixos Proton sem jogo instalado)..."

    local compat_dir="${STEAM_APPS}/compatdata"
    local acf_dir="${STEAM_APPS}"

    if [[ ! -d "$compat_dir" ]]; then
        warn "Diretório compatdata não encontrado."
        return
    fi

    local orphans=0
    local freed=0

    while IFS= read -r -d '' prefix_dir; do
        local app_id
        app_id=$(basename "$prefix_dir")

        # Verifica se existe ACF correspondente
        if ! ls "${acf_dir}/appmanifest_${app_id}.acf" &>/dev/null; then
            local s
            s=$(du -sm "$prefix_dir" 2>/dev/null | cut -f1)
            warn "Prefixo órfão encontrado: AppID $app_id (${s}MB)"
            ((orphans++))
            ((freed+=s))
        fi
    done < <(find "$compat_dir" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

    if [[ $orphans -gt 0 ]]; then
        warn "$orphans prefixo(s) órfão(s) encontrado(s) (~${freed}MB)."
        read -rp "Deseja remover os prefixos órfãos? [s/N] " confirm
        if [[ "$confirm" =~ ^[sS]$ ]]; then
            while IFS= read -r -d '' prefix_dir; do
                local app_id
                app_id=$(basename "$prefix_dir")
                if ! ls "${acf_dir}/appmanifest_${app_id}.acf" &>/dev/null; then
                    rm -rf "$prefix_dir" && log "Removido: $prefix_dir"
                fi
            done < <(find "$compat_dir" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
        else
            info "Nenhum prefixo removido."
        fi
    else
        log "Nenhum prefixo órfão encontrado."
    fi
}

# ----------------------------------------------------------------------------
# Mover biblioteca Steam para SD card via symlink
# ----------------------------------------------------------------------------
move_library_to_sd() {
    info "Configurando mover biblioteca Steam para SD card..."

    # Detecta SD card montado
    local sd_mount=""
    for mount in /run/media/mmcblk0p1 /run/media/deck /media/sdcard /mnt/sdcard; do
        if mountpoint -q "$mount" 2>/dev/null; then
            sd_mount="$mount"
            break
        fi
    done

    if [[ -z "$sd_mount" ]]; then
        warn "Nenhum SD card detectado. Monte o SD card e tente novamente."
        warn "Montagens verificadas: /run/media/mmcblk0p1, /run/media/deck"
        return
    fi

    info "SD card detectado em: $sd_mount"
    info "Espaço disponível: $(df -h "$sd_mount" | awk 'NR==2{print $4}')"

    local sd_steam="${sd_mount}/SteamLibrary"
    local src_dir="${STEAM_APPS}"

    if [[ -L "$src_dir" ]]; then
        log "steamapps já é um symlink: $(readlink "$src_dir")"
        return
    fi

    read -rp "Mover ${src_dir} para ${sd_steam}? Isso pode demorar. [s/N] " confirm
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        info "Operação cancelada."
        return
    fi

    mkdir -p "$sd_steam"

    info "Copiando biblioteca para SD card (isso pode demorar)..."
    if rsync -a --progress "$src_dir/" "$sd_steam/"; then
        mv "$src_dir" "${src_dir}.bak"
        ln -s "$sd_steam" "$src_dir"
        log "Biblioteca movida para $sd_steam e symlink criado."
        info "Backup original em: ${src_dir}.bak"
        info "Após verificar que tudo funciona, remova com: rm -rf ${src_dir}.bak"
    else
        err "Falha ao copiar. Operação cancelada."
    fi
}

# ----------------------------------------------------------------------------
# Relatório de espaço
# ----------------------------------------------------------------------------
show_disk_report() {
    echo ""
    echo "============================================="
    echo "  Relatório de Uso de Espaço"
    echo "============================================="
    df -h / 2>/dev/null | awk 'NR==1 || /^\//{ printf "%-20s %6s %6s %6s %5s\n", $1, $2, $3, $4, $5 }'
    echo ""
    size "Steam total:        $(dir_size "$STEAM_HOME")"
    size "Shader cache:       $(dir_size "${STEAM_APPS}/shadercache")"
    size "Download packages:  $(dir_size "${STEAM_HOME}/package")"
    size "Compatdata (Proton): $(dir_size "${STEAM_APPS}/compatdata")"
    size "Thumbnails:         $(dir_size "${HOME}/.local/share/thumbnails")"
    echo ""
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
main() {
    echo ""
    echo "============================================="
    echo "  Steam Deck - Otimização de Armazenamento"
    echo "============================================="

    show_disk_report

    clear_shader_cache
    clear_download_cache
    clear_thumbnails
    clear_orphan_compatdata

    echo ""
    read -rp "Deseja configurar symlink para SD card? [s/N] " sd_choice
    if [[ "$sd_choice" =~ ^[sS]$ ]]; then
        move_library_to_sd
    fi

    echo ""
    info "Espaço após limpeza:"
    df -h / 2>/dev/null | awk 'NR==1 || /^\//{ printf "%-20s %6s %6s %6s %5s\n", $1, $2, $3, $4, $5 }'
    echo ""
    log "Otimização de armazenamento concluída!"
}

main "$@"
