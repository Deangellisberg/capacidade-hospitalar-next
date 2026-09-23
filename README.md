## Estrutura do projeto (coleta de dados e banco)

```
capacidade-hospitalar-next/
├── README.md
├── requirements.txt
├── .gitignore
├── pipeline/
│   ├── 01_coleta.py         # coleta CNES-LT, SIH-RD e MSHL; filtra Recife
│   └── 02_transformacao.py  # trata tipo, nulo/vazio, consolida os 3 DataFrames
├── sql/
│   └── 01_schema.sql        # DDL do banco: 9 tabelas, PK/FK, domínios já semeados
├── dados/
│   ├── amostra/              # amostra pequena, versionada no Git
│   └── brutos/                # coleta completa, NÃO versionada (ver .gitignore)
│       ├── AAAAMM/            # uma pasta por competência (CNES-LT e SIH-RD)
│       └── complementares/    # MSHL (fonte anual, fora do padrão mensal)
└── docs/
    ├── regra_dias_internacao_mes.md    # regra de cálculo de pacientes-dia/ocupação
    ├── fonte_dados/
    │   ├── SCNES_DOMINIOS.XLS    # dicionário de domínios do SCNES 
    │   ├── dicionario_campos_p5.docx    # documentação detalhada dos campos do pipeline P5  
    │   ├── dicionario_campos_p5_simplificado.docx    # versão simplificada para consulta rápida
    │   ├── dominio_codeleito_tpleito_cnes.md    # explicação dos códigos de leitos no CNES 
    │   ├── dicionario_dominios_sih_rd.md    # domínios ESPEC/IDENT do SIH-RD, reconstruídos de fontes DATASUS
    │   └── leitos_dominio.csv    # tabela de referência dos tipos de leitos 
    └── justificativa_mudanca_basedados/
        ├── documentacao_fonte_hospitais_leitos_ms.md    # detalha a coleta e filtros aplicados aos dados de hospitais/leitos do MS
        └── justificativa_troca_fonte_cnes_st.md    # justificativa da troca da fonte CNES-ST 

```
## Como rodar a coleta do zero

### Pré-requisitos

- Python 3.13 (versões muito recentes, como 3.14+, ainda não têm suporte completo das bibliotecas usadas aqui)
- Acesso à internet (a coleta baixa direto de fontes públicas: DATASUS e Ministério da Saúde)

### Passo a passo

```bash
# 1. Clone o repositório
git clone https://github.com/Deangellisberg/capacidade-hospitalar-next.git
cd capacidade-hospitalar-next

# 2. Crie e ative o ambiente virtual (Python 3.13 especificamente)
py -3.13 -m venv .venv
source .venv/Scripts/activate      # Windows (Git Bash)
# source .venv/bin/activate        # macOS/Linux

# 3. Instale as dependências (versões fixadas — mesmas já testadas no projeto)
pip install -r requirements.txt

# 4. Rode a coleta e a transformação
python pipeline/01_coleta.py
python pipeline/02_transformacao.py
```

Isso coleta as três fontes de jan/2024 a dez/2026. Meses que ainda não aconteceram (ex.: os últimos meses de 2026, dependendo de quando você rodar) aparecem como "indisponível" no log — é esperado, não é erro. Rodar de novo não duplica nem refaz o que já foi coletado (a coleta é idempotente).

**Resultado esperado:** ao final, o log mostra um resumo com quantas competências deram certo, quantas foram puladas (já existiam), quantas ainda não estavam disponíveis na fonte, e quantas falharam de verdade. Se "Erros" vier zero, a coleta está completa.

**Qual arquivo usar:** dentro de `dados/brutos/`, cada fonte gera dois arquivos — um com o dado bruto (Pernambuco inteiro, ou Brasil inteiro no caso do MSHL) e outro só com Recife. Use sempre o que termina em `_recife.parquet`; o outro existe só como auditoria.

## Como criar o banco de dados

### Pré-requisitos

- PostgreSQL instalado, com `psql` acessível no terminal. No Windows, se o `psql --version` der "command not found" mesmo com o PostgreSQL instalado, é um problema de PATH — adicione a pasta `bin` da instalação (ex.: `C:\Program Files\PostgreSQL\<versão>\bin`) ao PATH do sistema ou do Git Bash (`~/.bashrc`).

### Passo a passo

```bash
# 1. Crie o banco do projeto, já forçando UTF-8 explicitamente
psql -U postgres -c "CREATE DATABASE capacidade_hospitalar WITH ENCODING 'UTF8' LC_COLLATE='Portuguese_Brazil.1252' LC_CTYPE='Portuguese_Brazil.1252' TEMPLATE=template0;"

# 2. Rode o schema (cria as 9 tabelas, com PK/FK e os domínios já semeados)
psql -U postgres -d capacidade_hospitalar -f sql/01_schema.sql --set ON_ERROR_STOP=1

# 3. Confirme que as 9 tabelas foram criadas
psql -U postgres -d capacidade_hospitalar -c "\dt"
```

**Sobre o `WITH ENCODING 'UTF8' ... TEMPLATE=template0`:** sem isso, o banco pode herdar um encoding diferente de UTF-8 (dependendo da configuração regional do Windows), fazendo acento sair quebrado em qualquer consulta depois. `TEMPLATE=template0` garante que a criação não herda nada de um template padrão já "contaminado". Se der erro reclamando do `LC_COLLATE`/`LC_CTYPE` (alguns Windows não têm esse locale instalado), usa a versão mais simples: `CREATE DATABASE capacidade_hospitalar WITH ENCODING 'UTF8' TEMPLATE=template0;`.

**Se você já criou o banco sem esses parâmetros e está vendo acento quebrado:** confirme o encoding atual com `psql -U postgres -d capacidade_hospitalar -c "SHOW server_encoding;"`. `server_encoding` só é definido na criação do banco — não tem como corrigir depois sem recriar. Apague o banco (`DROP DATABASE capacidade_hospitalar;`) e recrie com o comando acima.

**Sobre o `--set ON_ERROR_STOP=1`:** sem essa flag, o `psql -f` não para em erro — ele segue rodando o resto do script mesmo se uma linha falhar, mascarando o problema. Sempre use essa flag ao rodar scripts SQL neste projeto.

**Resultado esperado:** 9 tabelas (`lista_hospitais_gestao_propria`, `dim_estabelecimento`, `dom_tipo_leito`, `dom_codigo_leito`, `fato_leitos`, `dom_especialidade_sih`, `dom_tipo_aih`, `fato_internacoes`, `de_para_especialidade_leito`). As tabelas de domínio e o de-para de especialidade já vêm com dado (são referência fixa, não dependem de coleta); as demais ficam vazias até o `03_carga.py` (em desenvolvimento) popular com dado real.

**Teste de reprodutibilidade** (recomendado antes de qualquer entrega): apague e recrie o banco do zero, seguindo só os 3 comandos acima — se rodar sem nenhum erro, o schema está reprodutível.

## Fontes e dados coletados

| Fonte | O que traz | Frequência | Chave |
|---|---|---|---|
| **CNES-LT** | Quantidade de leitos por hospital e tipo (clínico, cirúrgico, etc.) | Mensal | `CNES` |
| **SIH-RD** | Internações: data de saída, dias de permanência, especialidade | Mensal | `CNES` |
| **MSHL** (Hospitais e Leitos/MS) | Nome do hospital, razão social, gestão, endereço | Anual | `CNES` |

| Campo (principais) | Fonte | Descrição |
|---|---|---|
| `CNES` | CNES-LT, SIH-RD, MSHL | Código do estabelecimento de saúde — chave de junção entre as três fontes, sem tabela-ponte |
| `CODUFMUN` | CNES-LT | Código do município (filtro: 261160 = Recife) |
| `TP_LEITO` | CNES-LT | Categoria do leito (1 = Cirúrgico, 2 = Clínico) |
| `CODLEITO` | CNES-LT | Especialidade específica do leito |
| `QT_EXIST` / `QT_SUS` | CNES-LT | Quantidade de leitos existentes / disponíveis ao SUS |
| `CGC_HOSP` | SIH-RD | CNPJ do hospital — mantido só como campo de auditoria, não é mais usado para join (as 16 unidades da Prefeitura não têm CNPJ próprio) |
| `DT_INTER` / `DT_SAIDA` | SIH-RD | Data de início e de saída do paciente |
| `DIAS_PERM` | SIH-RD | Dias de permanência internado |
| `ESPEC` | SIH-RD | Especialidade da internação |
| `IDENT` | SIH-RD | Tipo de AIH (1=Normal, 5=Longa permanência) — faz parte da chave primária de `fato_internacoes` |
| `NOME_ESTABELECIMENTO` | MSHL | Nome do hospital |
| `TP_GESTAO` | CNES-LT, MSHL | Esfera de gestão (M/E/D/S) |

Dicionário completo de todos os campos (incluindo os não usados diretamente pelas perguntas do Canvas, tipos de dado reais e tabelas de domínio) em `docs/fonte_dados/dicionario_campos_p5.docx`.

**Limitações conhecidas** (detalhadas em `docs/`):
- `fato_leitos` e `fato_internacoes` ligam com `dim_estabelecimento` por `cnes`, sem FK real (constraint) — o MSHL é publicado por ano e tem lacunas reais de cobertura. Sempre `LEFT JOIN` (nunca `INNER`), nunca descartando leito ou internação sem hospital correspondente.
- As competências mais recentes do SIH-RD chegam sistematicamente incompletas (defasagem estrutural do sistema).
