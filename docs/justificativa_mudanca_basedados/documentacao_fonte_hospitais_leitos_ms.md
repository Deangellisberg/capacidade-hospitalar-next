# Documentação técnica — Fonte de dados: nome e identificação dos hospitais

**Projeto:** P5 — Capacidade Hospitalar (SERMAC/Recife)
**Última atualização:** 17/09/2026

## Resumo (para qualquer pessoa do time)

O CNES tem uma peça de dado (`CNES-ST`) que deveria trazer nome e dados administrativos
dos hospitais, mas testamos com dado real e confirmamos que ela **não traz nome de
estabelecimento** — só código CNES e informação administrativa. Substituímos essa peça
por outra fonte pública do governo, chamada **"Hospitais e Leitos"**, que resolve isso e
ainda cobre o histórico mensal que o projeto precisa. Não muda nenhuma pergunta do Canvas
nem o escopo do projeto — é uma troca na camada de coleta de dados.

---

## A fonte adotada

- **Nome:** Hospitais e Leitos
- **Mantenedor:** Ministério da Saúde — Coordenação-Geral de Atenção Hospitalar e
  Domiciliar (CGHID/DAHU)
- **Portal:** https://dadosabertos.saude.gov.br/dataset/hospitais-e-leitos
- **Formato de download:** um `.zip` por ano, contendo um único `.csv` (ex.:
  `Leitos_csv_2026.zip` → `Leitos_2026.csv`)
- **URL de download direto:** `https://s3.sa-east-1.amazonaws.com/ckan.saude.gov.br/Leitos_SUS/Leitos_csv_{ano}.zip`
- **Encoding/separador confirmados:** `latin-1`, separado por `;`
- **Frequência de atualização:** mensal
- **Licença:** Creative Commons Atribuição-SemDerivações 3.0 (uso público permitido)
- **Dicionário de dados oficial:** https://s3.sa-east-1.amazonaws.com/ckan.saude.gov.br/Leitos_SUS/Dicion%C3%A1rio_Leito_hospitalar.pdf

## Colunas confirmadas (validado com dado real, arquivo de 2026)

```
COMP, REGIAO, UF, CO_IBGE, MUNICIPIO, MOTIVO_DESABILITACAO, CNES,
NOME_ESTABELECIMENTO, RAZAO_SOCIAL, TP_GESTAO, CO_TIPO_UNIDADE, DS_TIPO_UNIDADE,
NATUREZA_JURIDICA, DESC_NATUREZA_JURIDICA, NO_LOGRADOURO, NU_ENDERECO,
NO_COMPLEMENTO, NO_BAIRRO, CO_CEP, NU_TELEFONE, NO_EMAIL,
LEITOS_EXISTENTES, LEITOS_SUS,
UTI_TOTAL_EXIST, UTI_TOTAL_SUS, UTI_ADULTO_EXIST, UTI_ADULTO_SUS,
UTI_PEDIATRICO_EXIST, UTI_PEDIATRICO_SUS, UTI_NEONATAL_EXIST, UTI_NEONATAL_SUS,
UTI_QUEIMADO_EXIST, UTI_QUEIMADO_SUS, UTI_CORONARIANA_EXIST, UTI_CORONARIANA_SUS
```

**Colunas de interesse direto para o projeto:** `COMP` (competência, formato `AAAAMM`),
`CNES` (chave de junção com o CNES-LT), `NOME_ESTABELECIMENTO`, `RAZAO_SOCIAL`,
`TP_GESTAO`, `CO_IBGE`/`MUNICIPIO` (filtro geográfico).

## Tipos de dado reais (confirmado com `.dtypes`, não o tipo "oficial" de layout)

Esta é a **única das três fontes do pipeline que chega com tipo numérico real**
(`int64`/`float64`), diferente de CNES-LT e SIH-RD, que chegam com **todos** os campos
como texto (`object`) ao ler via PySUS.

| Campo | Tipo real |
|---|---|
| `COMP`, `CNES`, `CO_IBGE`, `CO_TIPO_UNIDADE`, `NATUREZA_JURIDICA`, `CO_CEP`, `LEITOS_EXISTENTES`, `LEITOS_SUS`, todos os `UTI_*` | `int64` |
| `MOTIVO_DESABILITACAO` | `float64` (por ter muitos valores nulos) |
| `REGIAO`, `UF`, `MUNICIPIO`, `NOME_ESTABELECIMENTO`, `RAZAO_SOCIAL`, `TP_GESTAO`, `DS_TIPO_UNIDADE`, `DESC_NATUREZA_JURIDICA`, endereço, contato | `object` |

**Ponto de atenção para a junção entre fontes:** o campo `CNES` aqui é `int64`, mas o
campo equivalente em CNES-LT e o `CGC_HOSP` do SIH-RD chegam como `object` (texto). Os
tipos precisam ser padronizados (mesma representação) antes de qualquer `JOIN` entre as
tabelas no `02_transformacao.py` — sem isso, a junção simplesmente não vai casar nenhuma
linha, mesmo que os valores "pareçam" iguais visualmente.



## Validação de Recife

`CO_IBGE = 261160` corresponde a Recife — **mesmo código e mesmo formato de 6 dígitos**
já usado no CNES (`CODUFMUN`), sem necessidade de conversão. Confirmado com dado real:
596 linhas retornadas para Recife só no arquivo de 2026, incluindo hospitais conhecidos
(Hospital das Clínicas, Hospital da Restauração, IMIP, Hospital Agamenon Magalhães,
entre outros).

## Cobertura temporal

O dataset é distribuído em arquivos anuais (não mensais). Para cobrir o recorte do
projeto (jul/2024–jun/2026), são necessários os arquivos de **2024, 2025 e 2026**.
O campo `COMP` dentro de cada arquivo identifica a competência mensal específica.

**Ainda não validado:** os arquivos de 2024 e 2025 são assumidos com o mesmo padrão de
nome de arquivo e estrutura de colunas do de 2026 (mesma convenção de URL), mas isso
ainda não foi confirmado rodando o pipeline contra dado real desses dois anos.

---

## Arquitetura final: as três fontes do pipeline

| Fonte | O que fornece | Chave de junção |
|---|---|---|
| CNES-LT (PySUS/FTP) | Quantidade de leitos por tipo (clínico, cirúrgico) | `CNES` |
| **Hospitais e Leitos (MS)** | Nome, razão social, gestão, endereço, total de leitos | `CNES` |
| SIH-RD (PySUS/FTP) | Internações, tempo de permanência | `CNES` |

As três se conectam pelo código `CNES`, que é a chave universal do cadastro de saúde
brasileiro.

## Qual foi o motivo real da troca (e qual não foi)

Vale ser precisa aqui, porque a nova fonte trouxe mais de um benefício, mas nem todos
pesaram igual na decisão:

- **Motivo principal, suficiente sozinho:** o CNES-ST não tinha nome de hospital. Esse
  foi o gatilho da troca — sem esse problema, não haveria motivo para mudar de fonte.
- **Motivo secundário, encontrado no processo, não planejado desde o início:** antes
  desta troca, usávamos um workaround (download manual do `tbEstabelecimento`) só para
  resolver o nome — mas esse workaround trazia apenas uma foto única (um mês), sem
  histórico. A nova fonte, além de resolver o nome, também tem histórico mensal desde
  2007, o que elimina essa segunda limitação de quebra — mas essa não foi a razão
  original de buscar uma fonte alternativa, foi um benefício descoberto ao validar os
  dados.
- **Não conta como motivo, mesmo estando disponível no dataset:** telefone, e-mail e
  endereço completo do estabelecimento vêm juntos nesta fonte, mas nenhuma pergunta do
  Canvas pede essa informação — não foram buscados e provavelmente não vão aparecer em
  nenhuma análise do projeto. Registrar isso evita justificar a troca com base em algo
  que não é, de fato, usado.

## Por que o CNES-ST foi descartado (não só substituído)

Não é uma fonte alternativa mantida "por precaução" — foi removida do pipeline porque a
nova fonte cobre tudo que o CNES-ST oferecia (`TP_GESTAO`, natureza jurídica, endereço) e
resolve a limitação que ele tinha (nome do hospital). Manter as duas seria redundância
sem ganho.

## Limitações conhecidas

- **Sem detalhamento clínico/cirúrgico:** este dataset só traz totais de leito (existente/
  SUS) e detalhamento de UTI por tipo — não separa "leito clínico" de "leito cirúrgico".
  Por isso o **CNES-LT continua sendo a fonte obrigatória** para a Pergunta 1 do Canvas.
- **Não substitui a lista da SERMAC:** o campo `TP_GESTAO` (M/E/D/S) indica esfera de
  financiamento, não "gestão própria" no sentido que a SERMAC usa (direta vs. OS
  contratada). A lista oficial de hospitais próprios continua sendo uma pendência
  separada, não resolvida por esta mudança.
- **Arquivos de 2024/2025 ainda não testados** (ver seção "Cobertura temporal" acima).

## Status

Implementado em `pipeline/01_coleta.py`. Testado e validado com o arquivo de 2026;
validação de 2024/2025 pendente na próxima execução completa do pipeline.
