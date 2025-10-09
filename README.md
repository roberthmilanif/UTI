# UTI – Otimizador de agenda de plantão

Este repositório contém uma ferramenta em Python para auxiliar na distribuição
balanceada de plantões. A heurística implementada considera restrições comuns
(como descanso mínimo entre turnos, indisponibilidades e número máximo de
plantões por pessoa) e tenta atender preferências individuais sempre que
possível.

## Como funciona

1. Prepare um arquivo de configuração em JSON (ou YAML) com a descrição dos
   plantões e a lista de profissionais elegíveis. Veja o arquivo
   [`exemplos/escala_exemplo.json`](exemplos/escala_exemplo.json) como ponto de
   partida.
2. Execute o otimizador informando o caminho para o arquivo de configuração:

   ```bash
   python -m plantao_optimizer.optimizer exemplos/escala_exemplo.json --iterations 600 --seed 42
   ```

3. Opcionalmente, salve o resultado em JSON usando `--dump-json`.

A saída apresenta um resumo com a quantidade de plantões por profissional, as
respectivas datas atribuídas, a sequência máxima de dias consecutivos trabalhados
e a pontuação da solução (quanto menor, melhor).

## Instalação

A aplicação depende apenas da biblioteca padrão do Python. Recursos adicionais
são opcionais e podem ser instalados conforme a necessidade:

- **YAML**: `pip install pyyaml`
- **Integração com iCloud (CalDAV)**: `pip install caldav`

Caso utilize timezones específicos, assegure-se de que o sistema possui os
dados de fuso horário atualizados (em distribuições Linux geralmente já estão
presentes; no Windows recomenda-se instalar o pacote `tzdata`).

## Integração com agenda do iCloud

É possível enviar automaticamente o resultado otimizado para um calendário do
iCloud usando o protocolo CalDAV. Siga os passos:

1. Gere uma senha específica de app na sua conta Apple ID.
2. Identifique o nome exato do calendário que receberá os eventos.
3. Execute o otimizador informando as credenciais:

   ```bash
   python -m plantao_optimizer.optimizer exemplos/escala_exemplo.json \
       --icloud-user "seu_usuario@icloud.com" \
       --icloud-app-password "SENHA-DO-APP" \
       --icloud-calendar "Plantões" \
       --icloud-timezone America/Sao_Paulo
   ```

   As credenciais também podem ser fornecidas via variáveis de ambiente:

   - `PLANTAO_ICLOUD_USER`
   - `PLANTAO_ICLOUD_APP_PASSWORD`
   - `PLANTAO_ICLOUD_CALENDAR`
   - `PLANTAO_ICLOUD_SERVER` (opcional, padrão `https://caldav.icloud.com/`)
   - `PLANTAO_ICLOUD_TIMEZONE` (opcional)

4. Por padrão, eventos previamente criados com o mesmo identificador de
   plantão serão substituídos. Use `--icloud-keep-existing` caso deseje manter
   os eventos existentes.

## Próximos passos sugeridos

- Ajustar penalidades e pesos para aproximar o comportamento das regras
  reais da escala.
- Adicionar novas restrições (folgas fixas, número mínimo de noites por mês,
  etc.).
- Implementar testes automatizados com cenários típicos do plantão.

