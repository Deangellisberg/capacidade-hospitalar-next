#  P5 — Capacidade Hospitalar

Pipeline de dados desenvolvido para coleta, tratamento, integração e análise de dados públicos de saúde, com foco na **capacidade hospitalar e nas internações do município de Recife/PE**.

O projeto integra dados do **CNES-LT**, **SIH-RD** e **MSHL**, transformando diferentes fontes em uma estrutura analítica armazenada em **PostgreSQL**.

---

##  Sumário

- [Sobre o projeto](#-sobre-o-projeto)
- [Arquitetura do pipeline](#-arquitetura-do-pipeline)
- [Fontes de dados](#-fontes-de-dados)
- [Recorte dos dados](#-recorte-dos-dados)
- [Estrutura do projeto](#-estrutura-do-projeto)
- [Pipeline](#-pipeline)
- [Banco de dados](#-banco-de-dados)
- [Modelo de integração](#-modelo-de-integração)
- [Regras de negócio](#-regras-de-negócio)
- [Recorte de leitos](#-recorte-de-leitos)
- [Validação dos dados](#-validação-dos-dados)
- [Configuração do ambiente](#-configuração-do-ambiente)
- [Execução](#-execução)
- [Análises e dashboard](#-análises-e-dashboard)
- [Reprodutibilidade](#-reprodutibilidade)
- [Limitações](#-limitações-conhecidas)
- [Documentação](#-documentação)
- [Status](#-status-do-projeto)

---

#  Sobre o projeto

O projeto **P5 — Capacidade Hospitalar** tem como objetivo construir uma base analítica capaz de relacionar:

- estabelecimentos de saúde;
- capacidade instalada;
- quantidade e tipos de leitos;
- internações hospitalares;
- especialidades;
- informações de gestão;
- competências de referência.

As principais fontes utilizadas são:

- **CNES-LT** — dados de leitos por estabelecimento e tipo;
- **SIH-RD** — registros reduzidos de internações;
- **MSHL** — informações complementares de hospitais e leitos.

O resultado esperado é uma base estruturada em PostgreSQL, permitindo consultas, análises exploratórias e posteriormente a construção de um dashboard.

---

#  Arquitetura do pipeline

```text
┌───────────────────────────────┐
│       Fontes públicas         │
│                               │
│  CNES-LT   SIH-RD   MSHL      │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│        01_coleta.py            │
│                               │
│ Coleta + filtro Recife        │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│         dados/brutos/          │
│                               │
│ Dados originais + recorte     │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│      02_transformacao.py      │
│                               │
│ Limpeza + padronização        │
│ Tipagem + consolidação        │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│      dados/consolidados/       │
│                               │
│ LT / RD / MSHL                │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│          03_carga.py          │
│                               │
│ Carga transacional            │
│ PostgreSQL                    │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│          PostgreSQL           │
│                               │
│ Dimensões + Fatos + Domínios  │
└───────────────┬───────────────┘
                │
                ▼
        ┌───────┴────────┐
        │                │
        ▼                ▼
     SQL / EDA       Dashboard
```

---

#  Fontes de dados

| Fonte | Conteúdo | Frequência | Integração |
|---|---|---|---|
| **CNES-LT** | Leitos existentes e leitos SUS por estabelecimento e tipo | Mensal | CNES |
| **SIH-RD** | Internações, permanência, especialidade e informações da AIH | Mensal | CNES |
| **MSHL** | Estabelecimento, gestão e informações de leitos | Anual | CNES |

## CNES-LT

Utilizado principalmente para representar a **capacidade instalada dos estabelecimentos**.

Principais campos:

```text
CNES
COMPETEN
TP_LEITO
CODLEITO
QT_EXIST
QT_SUS
```

## SIH-RD

Utilizado para representar as **internações hospitalares**.

Principais campos:

```text
N_AIH
COMPETEN
CNES
CGC_HOSP
ESPEC
IDENT
SEQUENCIA
DT_INTER
DT_SAIDA
DIAS_PERM
QT_DIARIAS
PROC_REA
MUNIC_RES
MUNIC_MOV
UF_ZI
IDADE
SEXO
MORTE
```

O campo `CGC_HOSP` é mantido para auditoria e não é utilizado como chave principal de integração.

## MSHL

Utilizado como fonte complementar para informações dos estabelecimentos.

Principais campos:

```text
CNES
COMP
CO_IBGE
MUNICIPIO
NOME_ESTABELECIMENTO
RAZAO_SOCIAL
LEITOS_EXISTENTES
LEITOS_SUS
TP_GESTAO
```

---

#  Recorte dos dados

O projeto trabalha com o município de **Recife/PE**.

**Código IBGE:**

```text
261160
```

A coleta foi estruturada para trabalhar com:

- competências mensais do CNES-LT;
- competências mensais do SIH-RD;
- dados anuais do MSHL.

## Evidência do Checkpoint 1

A validação apresentada no Checkpoint 1 utilizou a competência:

```text
202508
```

Referências utilizadas:

| Indicador | Resultado |
|---|---:|
| SIH-RD Recife | aproximadamente 29.936 linhas |
| Internações nas unidades da Prefeitura | aproximadamente 2.747 |
| Internações da Prefeitura sem hospital identificado | 0 |
| Leitos clínicos/cirúrgicos | 322 |
| Permanência média | 3,33 dias |
| `fato_internacoes` | 29.936 linhas |
| CNES com tamanho diferente de 7 | 0 |

> **Observação:** os arquivos atualmente presentes no pacote de desenvolvimento também possuem competências posteriores, utilizadas durante o desenvolvimento e os testes do pipeline.

---

#  Estrutura do projeto

```text
capacidade-hospitalar-next/
│
├── README.md
├── requirements.txt
├── .gitignore
│
├── pipeline/
│   ├── 01_coleta.py
│   ├── 02_transformacao.py
│   └── 03_carga.py
│
├── dados/
│   ├── amostra/
│   ├── brutos/
│   ├── consolidados/
│   └── rejeitados/
│
├── sql/
│   └── 01_schema.sql
│
├── analises/
│
├── dashboard/
│   ├── esqueleto-painel.html
│   └── ideia-de-visual-painel.md
│
├── docs/
│   ├── ata-16-09-26.md
│   ├── ata-17-09-26.md
│   ├── ata-21-09-26.md
│   ├── ata-22-09-26.md
│   │
│   ├── de-para/
│   │   └── de_para_p5_capacidade_hospitalar.xlsx
│   │
│   ├── fonte_dados/
│   │   ├── SCNES_DOMINIOS.XLS
│   │   ├── dicionario_campos_p5.docx
│   │   ├── dicionario_campos_p5_simplificado.docx
│   │   ├── dominio_codleito_tpleito_cnes.md
│   │   └── leitos_dominio.csv
│   │
│   └── justificativa_mudanca_basedados/
│       ├── documentacao_fonte_hospitais_leitos_ms.md
│       └── justificativa_troca_fonte_cnes_st.md
│
└── pitch/
    └── slides/
```

---

#  Pipeline

## 1. Coleta

Arquivo:

```text
pipeline/01_coleta.py
```

Responsabilidades:

- coletar CNES-LT;
- coletar SIH-RD;
- coletar MSHL;
- filtrar o município de Recife;
- salvar os dados brutos;
- preservar os arquivos para rastreabilidade.

### Execução

```bash
python pipeline/01_coleta.py
```

Os dados são armazenados em:

```text
dados/brutos/
```

Para CNES-LT e SIH-RD:

```text
dados/brutos/AAAAMM/
```

Para MSHL:

```text
dados/brutos/complementares/
```

Os arquivos terminados em:

```text
_recife.parquet
```

representam o recorte utilizado nas etapas seguintes.

---

## 2. Transformação

Arquivo:

```text
pipeline/02_transformacao.py
```

Responsabilidades:

- selecionar as colunas utilizadas pelo modelo;
- padronizar tipos;
- tratar valores vazios;
- padronizar códigos;
- padronizar o CNES;
- gerar a competência;
- consolidar os arquivos por fonte.

### Execução

```bash
python pipeline/02_transformacao.py
```

Arquivos gerados:

```text
dados/consolidados/LT_consolidado.parquet
dados/consolidados/RD_consolidado.parquet
dados/consolidados/MSHL_consolidado.parquet
```

O CNES do MSHL é padronizado para sete caracteres, preservando zeros à esquerda.

---

## 3. Carga

Arquivo:

```text
pipeline/03_carga.py
```

Responsável por carregar os arquivos consolidados no PostgreSQL.

### Execução normal

```bash
python pipeline/03_carga.py
```

### Teste sem persistência

```bash
python pipeline/03_carga.py --dry-run
```

O `dry-run` executa o processo de carga e realiza `ROLLBACK` ao final.

### Ordem lógica da carga

```text
dim_estabelecimento
        ↓
fato_leitos
        ↓
fato_internacoes
```

Os domínios são criados e populados pelo arquivo:

```text
sql/01_schema.sql
```

A carga utiliza as chaves definidas no banco e realiza atualização quando encontra registros existentes.

---

#  Banco de dados

O schema está definido em:

```text
sql/01_schema.sql
```

O modelo atual possui **9 tabelas**:

```text
lista_hospitais_gestao_propria
dim_estabelecimento
dom_tipo_leito
dom_codigo_leito
fato_leitos
dom_especialidade_sih
dom_tipo_aih
fato_internacoes
de_para_especialidade_leito
```

## Principais grupos

### Dimensão

```text
dim_estabelecimento
```

Representa os estabelecimentos de saúde.

### Fatos

```text
fato_leitos
fato_internacoes
```

Representam respectivamente:

- capacidade de leitos;
- registros de internações.

### Domínios

```text
dom_tipo_leito
dom_codigo_leito
dom_especialidade_sih
dom_tipo_aih
```

Centralizam classificações utilizadas pelo modelo.

---

#  Modelo de integração

O **CNES** é a principal chave de integração entre as fontes.

```text
                       CNES
                        │
            ┌───────────┼───────────┐
            │           │           │
           MSHL       CNES-LT     SIH-RD
            │           │           │
            ▼           ▼           ▼
      dim_estabelecimento
                    │
             ┌──────┴──────┐
             ▼             ▼
        fato_leitos   fato_internacoes
```

O campo `CGC_HOSP` do SIH-RD permanece disponível para auditoria, mas não é utilizado como chave principal de relacionamento.

Essa decisão considera o comportamento do campo no recorte utilizado pelo projeto.

---

#  Regras de negócio

## Internações

A chave primária de `fato_internacoes` é:

```text
(n_aih, competencia, ident)
```

O campo `IDENT` faz parte da chave porque uma mesma AIH pode aparecer em diferentes situações relacionadas à longa permanência.

Para contabilizar internações:

```sql
WHERE ident = '1'
```

O registro:

```text
ident = '5'
```

representa continuidade de longa permanência e não deve ser contabilizado como uma nova internação.

---

## Relacionamentos

As consultas devem priorizar:

```sql
LEFT JOIN
```

em vez de:

```sql
INNER JOIN
```

Isso evita eliminar registros de internações ou leitos quando não existe correspondência em alguma fonte complementar.

---

#  Recorte de leitos

O projeto utiliza o seguinte recorte:

| `TP_LEITO` | Classificação |
|---:|---|
| 1 | Cirúrgico |
| 2 | Clínico |

Na competência `202508`, o recorte representa:

```text
Leitos cirúrgicos: 52
Leitos clínicos:    270
-----------------------
Total:              322
```

O total considerando todos os tipos de leito é aproximadamente:

```text
942 leitos
```

Portanto, o recorte clínico/cirúrgico representa apenas uma parte da capacidade hospitalar total e essa diferença deve ser considerada nas análises e no dashboard.

---

#  Validação dos dados

O projeto possui scripts específicos para validação:

```text
teste_consolidados.py
teste_qualidade.py
teste_relacionamentos.py
teste_cnes.py
```

As validações verificam:

- estrutura dos arquivos;
- quantidade de registros;
- nomes das colunas;
- tipos dos dados;
- valores nulos;
- competências;
- relacionamento por CNES;
- relacionamento entre fontes;
- registros sem correspondência.

Esses testes são utilizados antes da carga definitiva para identificar inconsistências no processo de integração.

---

#  Configuração do ambiente

## Requisitos

- Python 3.11+
- PostgreSQL
- Git

## Criar ambiente virtual

Windows:

```powershell
python -m venv .venv
```

Ativar:

```powershell
.venv\Scripts\activate
```

## Instalar dependências

```bash
pip install -r requirements.txt
```

Principais bibliotecas:

```text
pandas
PySUS
SQLAlchemy
psycopg2-binary
python-dotenv
```

---

#  Configuração do PostgreSQL

A carga utiliza a variável de ambiente:

```text
DATABASE_URL
```

Formato:

```text
postgresql://usuario:senha@host:5432/capacidade_hospitalar
```

Exemplo local:

```text
DATABASE_URL=postgresql://postgres:SUA_SENHA@localhost:5432/capacidade_hospitalar
```

> **Importante:** não coloque senhas diretamente no código e não versione credenciais no Git.

Antes de executar `03_carga.py`, a variável `DATABASE_URL` deve estar configurada no ambiente utilizado.

---

#  Execução completa

Depois de configurar Python e PostgreSQL:

### 1. Coleta

```bash
python pipeline/01_coleta.py
```

### 2. Transformação

```bash
python pipeline/02_transformacao.py
```

### 3. Criação do banco

```bash
psql -U postgres -c "CREATE DATABASE capacidade_hospitalar WITH ENCODING 'UTF8' TEMPLATE=template0;"
```

### 4. Aplicação do schema

```bash
psql -U postgres -d capacidade_hospitalar -f sql/01_schema.sql --set ON_ERROR_STOP=1
```

### 5. Teste da carga

```bash
python pipeline/03_carga.py --dry-run
```

### 6. Carga definitiva

```bash
python pipeline/03_carga.py
```

### 7. Conferir tabelas

```bash
psql -U postgres -d capacidade_hospitalar -c "\dt"
```

---

#  Análises e dashboard

As análises exploratórias e consultas SQL devem ser armazenadas em:

```text
analises/
```

O objetivo é utilizar os dados efetivamente carregados no PostgreSQL para responder às perguntas definidas no projeto.

Entre as análises previstas:

- quantidade de internações nas unidades da Prefeitura;
- internações sem hospital identificado;
- capacidade instalada;
- permanência média;
- quantidade de registros por competência;
- validação do tamanho do CNES;
- comparação entre tipos de leitos.

O dashboard está organizado em:

```text
dashboard/
```

---

#  Reprodutibilidade

Para reproduzir o projeto:

```text
1. Clonar o repositório
2. Criar o ambiente virtual
3. Instalar as dependências
4. Criar o banco PostgreSQL
5. Executar o schema
6. Configurar DATABASE_URL
7. Executar a coleta ou utilizar os dados brutos disponíveis
8. Executar a transformação
9. Executar o dry-run da carga
10. Executar a carga definitiva
11. Executar as consultas de validação
12. Realizar as análises
```

Fluxo resumido:

```text
Coleta
   ↓
Dados brutos
   ↓
Transformação
   ↓
Parquet consolidado
   ↓
Validação
   ↓
PostgreSQL
   ↓
SQL / EDA
   ↓
Dashboard
```

---

#  Limitações conhecidas

### Periodicidade das fontes

O MSHL possui periodicidade anual, enquanto CNES-LT e SIH-RD possuem periodicidade mensal.

Consequentemente, nem toda competência das fontes mensais possui necessariamente uma correspondência direta no MSHL.

---

### Integração por CNES

O CNES é utilizado como principal identificador de integração.

Ainda assim, podem existir registros sem correspondência entre as fontes, especialmente devido às diferenças de cobertura e competência.

---

### CGC_HOSP

O campo `CGC_HOSP` do SIH-RD pode estar vazio e, por isso, não é utilizado como chave principal de integração.

---

### Recorte de leitos

O recorte:

```text
TP_LEITO IN (1, 2)
```

considera apenas leitos cirúrgicos e clínicos.

Portanto, os resultados não representam necessariamente toda a capacidade hospitalar disponível.

---

### Defasagem

A fonte SIH-RD pode apresentar defasagem de publicação das competências mais recentes.

---

#  Documentação

A documentação complementar está organizada em:

```text
docs/
```

## Fontes de dados

```text
docs/fonte_dados/
```

Contém documentação de campos, domínios e informações relacionadas às fontes utilizadas.

## De-para

```text
docs/de-para/
```

Contém o mapeamento utilizado no projeto:

```text
de_para_p5_capacidade_hospitalar.xlsx
```

## Justificativas técnicas

```text
docs/justificativa_mudanca_basedados/
```

Contém as justificativas relacionadas às fontes e decisões adotadas no modelo.

---

#  Status do projeto

## Concluído

- [x] Coleta das fontes
- [x] Filtragem de Recife
- [x] Transformação dos dados
- [x] Consolidação dos arquivos Parquet
- [x] Modelo relacional
- [x] Domínios
- [x] Validações iniciais
- [x] Pipeline de carga
- [x] Implementação de `dry-run`

## Em andamento

- [ ] Validação completa da carga
- [ ] Consultas analíticas
- [ ] EDA
- [ ] Dashboard
- [ ] Ensaios complementares do Checkpoint 1

---

#  Projeto

**P5 — Capacidade Hospitalar**

**NExT Dados 2026.1**  
**CESAR School**

Projeto desenvolvido em equipe para coleta, tratamento, integração e análise de dados públicos de saúde.