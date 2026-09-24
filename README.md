# P5 — Capacidade Hospitalar

Pipeline de dados para coleta, transformação, integração e análise de dados públicos de saúde, com foco na capacidade hospitalar e internações de Recife/PE.

## Objetivo

Integrar dados das fontes:

* **CNES-LT:** leitos por estabelecimento e tipo;
* **SIH-RD:** internações hospitalares;
* **MSHL:** informações complementares dos estabelecimentos.

Os dados são tratados e carregados em PostgreSQL para análises SQL, EDA e dashboard.

---

## Arquitetura

```text
CNES-LT ─┐
SIH-RD  ─┼─> Coleta ─> Dados Brutos
MSHL    ─┘                │
                          ▼
                    Transformação
                          │
                          ▼
                    Consolidados
                          │
                          ▼
                       Carga
                          │
                          ▼
                     PostgreSQL
                          │
                    ┌─────┴─────┐
                    ▼           ▼
                   EDA       Dashboard
```

---

## Estrutura

```text
capacidade-hospitalar-next/
│
├── pipeline/
│   ├── 01_coleta.py
│   ├── 02_transformacao.py
│   └── 03_carga.py
│
├── dados/
│   ├── brutos/
│   ├── consolidados/
│   └── rejeitados/
│
├── sql/
│   └── 01_schema.sql
│
├── analises/
├── dashboard/
├── docs/
├── requirements.txt
└── README.md
```

---

# Requisitos

* Git
* Python 3.13 (especificamente)
* PostgreSQL
* Acesso à internet para a coleta

---

# Instalação

## 1. Clonar o projeto

A branch de desenvolvimento é `develop`.

```bash
git clone -b develop https://github.com/Deangellisberg/capacidade-hospitalar-next.git
cd capacidade-hospitalar-next
```

Confirme:

```bash
git branch --show-current
```

Resultado esperado:

```text
develop
```

## 2. Criar ambiente virtual

Windows:

```powershell
python -m venv .venv
.venv\Scripts\activate
```

Linux/macOS:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

## 3. Instalar dependências

```bash
pip install -r requirements.txt
```

---

# PostgreSQL

Crie o banco:

```bash
psql -U postgres -c "CREATE DATABASE capacidade_hospitalar WITH ENCODING 'UTF8' TEMPLATE=template0;"
```

Aplique o schema:

```bash
psql -U postgres -d capacidade_hospitalar -f sql/01_schema.sql --set ON_ERROR_STOP=1
```

Configure a conexão através da variável:

```text
DATABASE_URL
```

Exemplo no PowerShell:

```powershell
$env:DATABASE_URL="postgresql://postgres:SUA_SENHA@localhost:5432/capacidade_hospitalar"
```

---

# Execução

O pipeline possui três etapas:

### 1. Coleta

```bash
python pipeline/01_coleta.py
```

Coleta e filtra os dados para Recife.

### 2. Transformação

```bash
python pipeline/02_transformacao.py
```

Padroniza, trata e consolida os dados em:

```text
dados/consolidados/
├── LT_consolidado.parquet
├── RD_consolidado.parquet
└── MSHL_consolidado.parquet
```

### 3. Carga

Teste antes da persistência:

```bash
python pipeline/03_carga.py --dry-run
```

Carga definitiva:

```bash
python pipeline/03_carga.py
```

---

# Validação

Testes disponíveis:

```bash
python teste_consolidados.py
python teste_qualidade.py
python teste_relacionamentos.py
python teste_cnes.py
```

As validações verificam principalmente:

* registros e colunas;
* tipos e valores nulos;
* competências;
* relacionamentos por CNES;
* correspondência entre fontes.

---

# Modelo de dados

Principais tabelas:

```text
dim_estabelecimento
fato_leitos
fato_internacoes
```

Domínios:

```text
dom_tipo_leito
dom_codigo_leito
dom_especialidade_sih
dom_tipo_aih
```

Relacionamento principal:

```text
CNES
  │
  ├── MSHL
  ├── CNES-LT
  └── SIH-RD
```

O `CNES` é o principal identificador de integração entre as fontes.

---

# Regras principais

### Internações

A chave de `fato_internacoes` é:

```text
(n_aih, competencia, ident)
```

Para contabilização de internações:

```sql
WHERE ident = '1'
```

### Leitos

O recorte clínico/cirúrgico utiliza:

```text
TP_LEITO IN (1, 2)
```

### Competências

CNES-LT e SIH-RD possuem periodicidade mensal.
MSHL possui periodicidade anual.

---

# Fluxo de desenvolvimento

A `develop` é a branch de integração.

Não trabalhe diretamente nela.

```text
develop
   │
   ▼
branch da tarefa
   │
   ▼
desenvolvimento + testes
   │
   ▼
commit
   │
   ▼
push
   │
   ▼
Pull Request
   │
   ▼
develop
```

Criar uma branch:

```bash
git switch develop
git pull origin develop
git switch -c minha-tarefa
```

Enviar:

```bash
git add .
git commit -m "tipo: descrição"
git push -u origin minha-tarefa
```

---

# Documentação

Documentações complementares:

```text
docs/
├── de-para/
├── fonte_dados/
└── justificativa_mudanca_basedados/
```

---

# Status

* [x] Coleta
* [x] Transformação
* [x] Consolidação
* [x] Schema PostgreSQL
* [x] Validações
* [x] Pipeline de carga
* [x] Dry-run
* [ ] Análises finais
* [ ] Dashboard

---

## Projeto

**P5 — Capacidade Hospitalar**
**NExT Dados — CESAR School**
