# P5 — Capacidade Hospitalar

Pipeline de dados desenvolvido para coleta, tratamento, integração e análise de dados públicos de saúde, com foco na capacidade hospitalar e nas internações do município de Recife/PE.

O projeto integra dados provenientes do CNES-LT, SIH-RD e MSHL, transformando diferentes fontes de dados em uma estrutura analítica armazenada em PostgreSQL.

---

## Sumário

* [Sobre o projeto](#sobre-o-projeto)
* [Arquitetura](#arquitetura)
* [Fontes de dados](#fontes-de-dados)
* [Recorte dos dados](#recorte-dos-dados)
* [Estrutura do projeto](#estrutura-do-projeto)
* [Pré-requisitos](#pré-requisitos)
* [Baixando o projeto do GitHub](#baixando-o-projeto-do-github)
* [Configuração do ambiente Python](#configuração-do-ambiente-python)
* [Configuração do PostgreSQL](#configuração-do-postgresql)
* [Configuração da conexão](#configuração-da-conexão)
* [Execução do pipeline](#execução-do-pipeline)
* [Validação dos dados](#validação-dos-dados)
* [Banco de dados](#banco-de-dados)
* [Modelo de integração](#modelo-de-integração)
* [Regras de negócio](#regras-de-negócio)
* [Recorte de leitos](#recorte-de-leitos)
* [Análises e dashboard](#análises-e-dashboard)
* [Reprodutibilidade](#reprodutibilidade)
* [Solução de problemas](#solução-de-problemas)
* [Limitações conhecidas](#limitações-conhecidas)
* [Documentação](#documentação)
* [Status do projeto](#status-do-projeto)

---

# Sobre o projeto

O projeto P5 — Capacidade Hospitalar tem como objetivo construir uma base analítica capaz de relacionar:

* estabelecimentos de saúde;
* capacidade instalada;
* quantidade e tipos de leitos;
* internações hospitalares;
* especialidades;
* informações de gestão;
* competências de referência.

As principais fontes utilizadas são:

* CNES-LT — dados de leitos por estabelecimento e tipo;
* SIH-RD — registros reduzidos de internações;
* MSHL — informações complementares de hospitais e leitos.

O resultado esperado é uma base estruturada em PostgreSQL, permitindo consultas SQL, análises exploratórias e posteriormente a construção de um dashboard.

---

# Arquitetura

```text
┌───────────────────────────────┐
│        Fontes públicas        │
│                               │
│  CNES-LT   SIH-RD   MSHL      │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│         01_coleta.py          │
│                               │
│  Coleta + filtro Recife       │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│         dados/brutos/         │
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
│      dados/consolidados/      │
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

# Fontes de dados

| Fonte   | Conteúdo                                                     | Frequência | Integração |
| ------- | ------------------------------------------------------------ | ---------- | ---------- |
| CNES-LT | Leitos existentes e leitos SUS por estabelecimento e tipo    | Mensal     | CNES       |
| SIH-RD  | Internações, permanência, especialidade e informações da AIH | Mensal     | CNES       |
| MSHL    | Estabelecimento, gestão e informações de leitos              | Anual      | CNES       |

## CNES-LT

Utilizado principalmente para representar a capacidade instalada dos estabelecimentos.

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

Utilizado para representar as internações hospitalares.

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

# Recorte dos dados

O projeto trabalha com o município de Recife/PE.

Código IBGE:

```text
261160
```

A coleta foi estruturada para trabalhar com:

* competências mensais do CNES-LT;
* competências mensais do SIH-RD;
* dados anuais do MSHL.

## Evidência do Checkpoint 1

A validação apresentada no Checkpoint 1 utilizou a competência:

```text
202508
```

Referências utilizadas:

| Indicador                                           |                     Resultado |
| --------------------------------------------------- | ----------------------------: |
| SIH-RD Recife                                       | aproximadamente 29.936 linhas |
| Internações nas unidades da Prefeitura              |         aproximadamente 2.747 |
| Internações da Prefeitura sem hospital identificado |                             0 |
| Leitos clínicos/cirúrgicos                          |                           322 |
| Permanência média                                   |                     3,33 dias |
| `fato_internacoes`                                  |                 29.936 linhas |
| CNES com tamanho diferente de 7                     |                             0 |

> Observação: os arquivos atualmente presentes no pacote de desenvolvimento também possuem competências posteriores, utilizadas durante o desenvolvimento e os testes do pipeline.

---

# Estrutura do projeto

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

# Pré-requisitos

Antes de iniciar, é necessário possuir:

* Git;
* Python 3.13 especificamente;
* PostgreSQL;
* acesso ao terminal;
* conexão com a internet para a etapa de coleta.

## Verificar o Python

```bash
python --version
```

Exemplo:

```text
Python 3.11.9
```

## Verificar o Git

```bash
git --version
```

## Verificar o PostgreSQL

```bash
psql --version
```

---

# Baixando o projeto do GitHub

## 1. Instalar o Git

Caso ainda não possua o Git instalado, faça a instalação pelo site oficial:

https://git-scm.com/

Depois da instalação, abra um novo terminal e confirme:

```bash
git --version
```

---

## 2. Clonar o repositório

No terminal, navegue até a pasta onde deseja armazenar o projeto.

Exemplo no Windows:

```powershell
cd C:\Users\SeuUsuario\Desktop
```

Clone o repositório:

```bash
git clone https://github.com/Deangellisberg/capacidade-hospitalar-next.git
```

Entre na pasta:

```bash
cd capacidade-hospitalar-next
```

---

## 3. Conferir o repositório

Execute:

```bash
git status
```

Para visualizar as branches disponíveis:

```bash
git branch -a
```

A branch principal normalmente será:

```text
main
```

Caso seja necessário trabalhar na branch de desenvolvimento utilizada no projeto:

```bash
git checkout teste-validacao-dados
```

Caso a branch ainda não exista localmente:

```bash
git fetch origin
git checkout -b teste-validacao-dados origin/teste-validacao-dados
```

---

# Configuração do ambiente Python

É recomendado utilizar um ambiente virtual para isolar as dependências do projeto.

## Windows

Dentro da pasta do projeto:

```powershell
python -m venv .venv
```

Ative o ambiente:

```powershell
.venv\Scripts\activate
```

Após a ativação, o terminal deverá apresentar algo semelhante a:

```text
(.venv) C:\...\capacidade-hospitalar-next>
```

---

## Linux / macOS

Criar o ambiente:

```bash
python3 -m venv .venv
```

Ativar:

```bash
source .venv/bin/activate
```

---

## Atualizar o pip

```bash
python -m pip install --upgrade pip
```

---

## Instalar as dependências

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

Para conferir os pacotes instalados:

```bash
pip list
```

---

# Configuração do PostgreSQL

O projeto utiliza PostgreSQL como banco de dados analítico.

## 1. Criar o banco

Com o PostgreSQL instalado e o serviço ativo:

```bash
psql -U postgres -c "CREATE DATABASE capacidade_hospitalar WITH ENCODING 'UTF8' TEMPLATE=template0;"
```

Caso o banco já exista, não é necessário criá-lo novamente.

---

## 2. Aplicar o schema

Na raiz do projeto:

```bash
psql -U postgres -d capacidade_hospitalar -f sql/01_schema.sql --set ON_ERROR_STOP=1
```

O schema cria as tabelas, chaves, relacionamentos e domínios utilizados pelo projeto.

---

## 3. Conferir as tabelas

```bash
psql -U postgres -d capacidade_hospitalar -c "\dt"
```

O modelo atual possui:

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

---

# Configuração da conexão

A carga utiliza a variável de ambiente:

```text
DATABASE_URL
```

Formato:

```text
postgresql://usuario:senha@host:5432/capacidade_hospitalar
```

Exemplo:

```text
DATABASE_URL=postgresql://postgres:SUA_SENHA@localhost:5432/capacidade_hospitalar
```

> Importante: nunca publique senhas ou outras credenciais no GitHub.

## Windows — configuração temporária

No PowerShell:

```powershell
$env:DATABASE_URL="postgresql://postgres:SUA_SENHA@localhost:5432/capacidade_hospitalar"
```

Confirmar:

```powershell
$env:DATABASE_URL
```

Essa configuração permanece disponível enquanto o terminal estiver aberto.

---

## Windows — configuração permanente

Se desejar configurar a variável no ambiente do Windows:

```powershell
[Environment]::SetEnvironmentVariable(
    "DATABASE_URL",
    "postgresql://postgres:SUA_SENHA@localhost:5432/capacidade_hospitalar",
    "User"
)
```

Depois disso, feche e abra novamente o terminal.

Confirme:

```powershell
$env:DATABASE_URL
```

---

# Execução do pipeline

O pipeline possui três etapas principais:

```text
01_coleta.py
      |
      v
02_transformacao.py
      |
      v
03_carga.py
```

---

## 1. Coleta

Arquivo:

```text
pipeline/01_coleta.py
```

Responsabilidades:

* coletar CNES-LT;
* coletar SIH-RD;
* coletar MSHL;
* filtrar Recife;
* salvar dados brutos;
* preservar os arquivos para rastreabilidade.

Executar:

```bash
python pipeline/01_coleta.py
```

Os dados são armazenados em:

```text
dados/brutos/
```

CNES-LT e SIH-RD:

```text
dados/brutos/AAAAMM/
```

MSHL:

```text
dados/brutos/complementares/
```

Arquivos terminados em:

```text
_recife.parquet
```

representam o recorte de Recife utilizado pelas etapas seguintes.

> Atenção: a coleta depende da disponibilidade das fontes externas. Competências já existentes podem ser ignoradas pelo script para evitar downloads desnecessários.

---

## 2. Transformação

Arquivo:

```text
pipeline/02_transformacao.py
```

Responsabilidades:

* selecionar colunas;
* padronizar tipos;
* tratar valores vazios;
* padronizar códigos;
* padronizar CNES;
* gerar competência;
* consolidar arquivos por fonte.

Executar:

```bash
python pipeline/02_transformacao.py
```

Arquivos gerados:

```text
dados/consolidados/LT_consolidado.parquet
dados/consolidados/RD_consolidado.parquet
dados/consolidados/MSHL_consolidado.parquet
```

---

## 3. Carga

Arquivo:

```text
pipeline/03_carga.py
```

Responsável pela carga dos arquivos consolidados no PostgreSQL.

### Teste sem persistência

Antes da carga definitiva, execute:

```bash
python pipeline/03_carga.py --dry-run
```

O `dry-run` executa o processo de preparação da carga e realiza `ROLLBACK` ao final.

### Carga definitiva

Depois da validação:

```bash
python pipeline/03_carga.py
```

---

# Validação dos dados

Antes da carga definitiva, execute os testes disponíveis no projeto.

## Validar consolidados

```bash
python teste_consolidados.py
```

## Validar qualidade

```bash
python teste_qualidade.py
```

## Validar relacionamentos

```bash
python teste_relacionamentos.py
```

## Validar CNES

```bash
python teste_cnes.py
```

As validações verificam:

* quantidade de registros;
* colunas;
* tipos;
* valores nulos;
* competências;
* relacionamento por CNES;
* relacionamento entre fontes;
* possíveis registros sem correspondência.

---

# Banco de dados

O schema está definido em:

```text
sql/01_schema.sql
```

O modelo possui três grupos principais.

## Dimensão

```text
dim_estabelecimento
```

Representa os estabelecimentos de saúde.

## Fatos

```text
fato_leitos
fato_internacoes
```

Representam:

* capacidade de leitos;
* internações.

## Domínios

```text
dom_tipo_leito
dom_codigo_leito
dom_especialidade_sih
dom_tipo_aih
```

Centralizam classificações utilizadas pelo modelo.

---

# Modelo de integração

O CNES é a principal chave de integração.

```text
                       CNES
                        |
            +-----------+-----------+
            |           |           |
           MSHL       CNES-LT     SIH-RD
            |           |           |
            +-----------+-----------+
                        |
                        v
              dim_estabelecimento
                        |
                 +------+------+
                 |             |
                 v             v
            fato_leitos  fato_internacoes
```

O campo `CGC_HOSP` permanece disponível para auditoria, mas não é utilizado como chave principal de relacionamento.

---

# Regras de negócio

## Internações

A chave primária de `fato_internacoes` é:

```text
(n_aih, competencia, ident)
```

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

Isso evita eliminar registros quando não existe correspondência em uma fonte complementar.

---

# Recorte de leitos

O projeto utiliza:

| `TP_LEITO` | Classificação |
| ---------: | ------------- |
|          1 | Cirúrgico     |
|          2 | Clínico       |

Na competência `202508`:

```text
Cirúrgicos: 52
Clínicos:   270
----------------
Total:      322
```

O total considerando todos os tipos de leito é aproximadamente:

```text
942 leitos
```

Portanto, o recorte clínico/cirúrgico não representa necessariamente toda a capacidade hospitalar.

---

# Análises e dashboard

As análises exploratórias e consultas SQL devem ser armazenadas em:

```text
analises/
```

O dashboard está organizado em:

```text
dashboard/
```

Entre as análises previstas:

* quantidade de internações nas unidades da Prefeitura;
* internações sem hospital identificado;
* capacidade instalada;
* permanência média;
* registros por competência;
* validação do tamanho do CNES;
* comparação entre tipos de leitos.

---

# Fluxo completo de execução

```text
1. Clonar o repositório
        |
2. Criar o ambiente virtual
        |
3. Instalar as dependências
        |
4. Criar o banco PostgreSQL
        |
5. Aplicar o schema
        |
6. Configurar DATABASE_URL
        |
7. Executar a coleta
        |
8. Executar a transformação
        |
9. Executar as validações
        |
10. Executar o dry-run
        |
11. Executar a carga
        |
12. Executar consultas SQL / EDA
        |
13. Dashboard
```

---

# Reprodutibilidade

Para reproduzir o projeto:

## 1. Clonar

```bash
git clone https://github.com/Deangellisberg/capacidade-hospitalar-next.git
cd capacidade-hospitalar-next
```

## 2. Criar ambiente virtual

```bash
python -m venv .venv
```

## 3. Ativar no Windows

```powershell
.venv\Scripts\activate
```

## 4. Instalar dependências

```bash
pip install -r requirements.txt
```

## 5. Criar banco

```bash
psql -U postgres -c "CREATE DATABASE capacidade_hospitalar WITH ENCODING 'UTF8' TEMPLATE=template0;"
```

## 6. Aplicar schema

```bash
psql -U postgres -d capacidade_hospitalar -f sql/01_schema.sql --set ON_ERROR_STOP=1
```

## 7. Configurar conexão

```powershell
$env:DATABASE_URL="postgresql://postgres:SUA_SENHA@localhost:5432/capacidade_hospitalar"
```

## 8. Executar coleta

```bash
python pipeline/01_coleta.py
```

## 9. Executar transformação

```bash
python pipeline/02_transformacao.py
```

## 10. Executar validações

```bash
python teste_consolidados.py
python teste_qualidade.py
python teste_relacionamentos.py
python teste_cnes.py
```

## 11. Executar dry-run

```bash
python pipeline/03_carga.py --dry-run
```

## 12. Executar carga

```bash
python pipeline/03_carga.py
```

---

# Solução de problemas

## `python` não é reconhecido

Verifique:

```bash
python --version
```

Caso o comando não funcione, confirme se o Python está instalado e configurado no `PATH`.

---

## Ambiente virtual não ativado

O terminal deve apresentar:

```text
(.venv)
```

No Windows:

```powershell
.venv\Scripts\activate
```

---

## Dependência não encontrada

Execute:

```bash
pip install -r requirements.txt
```

---

## PostgreSQL não conecta

Confira:

```bash
psql --version
```

Verifique também:

* serviço do PostgreSQL ativo;
* usuário;
* senha;
* porta;
* nome do banco;
* `DATABASE_URL`.

---

## Banco não encontrado

Verifique os bancos disponíveis:

```bash
psql -U postgres -l
```

Procure por:

```text
capacidade_hospitalar
```

---

## Tabelas não existem

Execute:

```bash
psql -U postgres -d capacidade_hospitalar -f sql/01_schema.sql --set ON_ERROR_STOP=1
```

---

## Erro relacionado à `DATABASE_URL`

No PowerShell:

```powershell
$env:DATABASE_URL
```

Se estiver vazio:

```powershell
$env:DATABASE_URL="postgresql://postgres:SUA_SENHA@localhost:5432/capacidade_hospitalar"
```

---

## Erro durante a coleta

A etapa de coleta depende das fontes públicas externas.

Verifique:

* conexão com a internet;
* disponibilidade das fontes;
* competência solicitada;
* mensagens apresentadas pelo `01_coleta.py`.

---

# Limitações conhecidas

### Periodicidade

O MSHL possui periodicidade anual, enquanto CNES-LT e SIH-RD possuem periodicidade mensal.

Por isso, nem toda competência das fontes mensais possui correspondência direta no MSHL.

### Integração por CNES

O CNES é o principal identificador de integração, mas podem existir registros sem correspondência entre as fontes devido às diferenças de cobertura e competência.

### CGC_HOSP

O campo `CGC_HOSP` pode estar vazio e não é utilizado como chave principal.

### Recorte de leitos

O filtro:

```text
TP_LEITO IN (1, 2)
```

considera apenas leitos clínicos e cirúrgicos.

### Defasagem

O SIH-RD pode apresentar defasagem de publicação das competências mais recentes.

---

# Documentação

A documentação complementar está organizada em:

```text
docs/
```

## Fontes de dados

```text
docs/fonte_dados/
```

Contém documentação dos campos, domínios e fontes utilizadas.

## De-para

```text
docs/de-para/
```

Contém:

```text
de_para_p5_capacidade_hospitalar.xlsx
```

## Justificativas técnicas

```text
docs/justificativa_mudanca_basedados/
```

Contém documentação das decisões relacionadas às fontes e ao modelo.

---

# Status do projeto

## Concluído

* [x] Coleta das fontes
* [x] Filtragem de Recife
* [x] Transformação
* [x] Consolidação dos Parquets
* [x] Modelo relacional
* [x] Domínios
* [x] Validações iniciais
* [x] Pipeline de carga
* [x] Implementação de `dry-run`

## Em andamento

* [ ] Validação completa da carga
* [ ] Consultas analíticas
* [ ] EDA
* [ ] Dashboard
* [ ] Ensaios complementares do Checkpoint 1

---

# Projeto

**P5 — Capacidade Hospitalar**

**NExT Dados 2026.1**
**CESAR School**

Projeto desenvolvido em equipe para coleta, tratamento, integração e análise de dados públicos de saúde.
