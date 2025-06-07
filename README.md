# Passômetro de Casos - UTI

Este é um aplicativo simples em Flask para registrar e acompanhar casos de pacientes em leitos de UTI. A aplicação permite adicionar, visualizar e remover casos, funcionando como um "passômetro" digital para médicos.

## Requisitos
- Python 3
- Dependências listadas em `requirements.txt`

## Instalação
1. Crie um ambiente virtual (opcional, mas recomendado):
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
2. Instale as dependências:
   ```bash
   pip install -r requirements.txt
   ```

## Uso
Execute a aplicação com:
```bash
python app.py
```
Acesse `http://localhost:5000` em seu navegador para usar a interface.

Os casos são armazenados em um banco SQLite (`cases.db`) no próprio diretório.
