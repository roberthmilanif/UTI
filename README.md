# Steam Deck - Suite de Otimização

Scripts shell para otimizar o Steam Deck nas áreas de **performance**, **armazenamento**, **bateria** e **rede**.

## Instalação

```bash
git clone https://github.com/roberthmilanif/UTI.git
cd UTI
chmod +x optimize.sh scripts/*.sh
```

## Uso

### Menu interativo
```bash
sudo ./optimize.sh
```

### Executar tudo de uma vez
```bash
sudo ./optimize.sh --all
```

### Módulos individuais

```bash
# Performance: CPU governor, zRAM, swap, I/O scheduler
sudo ./optimize.sh --performance

# Armazenamento: limpar caches, shader cache, SD card
./optimize.sh --storage

# Bateria: perfis de energia e TDP
sudo ./optimize.sh --battery economy      # máxima duração
sudo ./optimize.sh --battery balanced     # padrão
sudo ./optimize.sh --battery performance  # máxima performance

# Rede: TCP tuning, BBR, DNS, buffers de download
sudo ./optimize.sh --network
```

---

## O que cada módulo faz

### Performance (`scripts/performance.sh`)

| Otimização | Detalhe |
|---|---|
| CPU Governor | Define `schedutil` — balanceia performance e consumo |
| CPU Boost | Ativa turbo boost do processador |
| vm.swappiness | Reduz de 60 → 10 para priorizar RAM |
| zRAM | Cria swap comprimido na RAM (50% da RAM, lz4) |
| I/O Scheduler | Define `mq-deadline` para menor latência de disco |
| Transparent Huge Pages | Modo `madvise` otimizado para jogos |
| Prioridade de processos | Permite nice negativo para jogos |

### Armazenamento (`scripts/storage.sh`)

| Operação | Detalhe |
|---|---|
| Shader cache | Remove `.cache` e `.log` acumulados (regenerado automaticamente) |
| Download cache | Remove packages do Steam com mais de 7 dias |
| Mesa shader cache | Limpa cache de shaders do driver Mesa/Proton |
| Thumbnails | Remove miniaturas com mais de 30 dias |
| Prefixos Proton órfãos | Detecta e remove prefixos de jogos desinstalados |
| Symlink SD card | Move biblioteca Steam para o cartão SD com symlink |

### Bateria (`scripts/battery.sh`)

| Perfil | CPU Governor | TDP | Brilho | Auto-suspend |
|---|---|---|---|---|
| `economy` | powersave | 3W | 30% | 5 min |
| `balanced` | schedutil | 8W | 60% | 15 min |
| `performance` | performance | 15W | 100% | off |

Também configura:
- WiFi power management
- Runtime PM para dispositivos PCI/USB
- Desativa serviços desnecessários (bluetooth, cups, avahi)
- Cria serviço systemd para persistir o perfil

> **Nota:** Controle de TDP requer [`ryzenadj`](https://github.com/FlyGoat/RyzenAdj). Sem ele, use o menu Quick Access do Steam Deck (botão `...`).

### Rede (`scripts/network.sh`)

| Otimização | Detalhe |
|---|---|
| Buffers TCP | rmem/wmem máximos de 128MB para downloads rápidos |
| TCP BBR | Algoritmo moderno do Google para maior throughput |
| TCP Fast Open | Reduz latência em conexões repetidas |
| Keep-alive | 60s — mantém sessão Steam ativa |
| DNS | Cloudflare 1.1.1.1 + Google 8.8.8.8 com cache |
| DNS over TLS | Privacidade nas consultas DNS |
| NIC tuning | GRO/TSO ativados, ring buffer aumentado |

---

## Requisitos

- **Sistema:** SteamOS 3.x ou Arch Linux no Steam Deck
- **Root/sudo:** necessário para performance, bateria e rede
- **Opcional:** `ryzenadj` para controle preciso de TDP

## Reverter mudanças

As configurações de sysctl são armazenadas em:
- `/etc/sysctl.d/99-steamdeck-perf.conf` — performance
- `/etc/sysctl.d/99-steamdeck-net.conf` — rede

Para remover:
```bash
sudo rm -f /etc/sysctl.d/99-steamdeck-*.conf
sudo sysctl --system
```

Configurações de DNS em:
```bash
sudo rm -f /etc/systemd/resolved.conf.d/99-steamdeck-dns.conf
sudo systemctl restart systemd-resolved
```

Serviços de perfil de bateria:
```bash
sudo systemctl disable steamdeck-battery-economy
sudo rm -f /etc/systemd/system/steamdeck-battery-*.service
```
