# Justificativa técnica — Troca de fonte de dados (CNES-ST)

**Projeto:** P5 — Capacidade Hospitalar (SERMAC/Recife)
**Data:** 17/09/2026

## Resumo

Substituímos a fonte **CNES-ST (Estabelecimentos)** pelo dataset público **"Hospitais e
Leitos"**, do Ministério da Saúde (dadosabertos.saude.gov.br). Não há mudança de escopo,
de problema de negócio ou de perguntas analíticas — a troca é estritamente técnica, na
camada de coleta de dados.

## Motivo da troca

Ao testar o CNES-ST com dado real, confirmamos que essa fonte **não contém o nome dos
estabelecimentos** — apenas código CNES e dados administrativos (gestão, natureza
jurídica). Essa limitação já constava como item a verificar no Canvas do projeto
("nome, natureza jurídica, gestão, instalações [verificar]"). Sem nome de hospital, o
painel final ficaria ilegível para o decisor (mostraria apenas códigos numéricos).

## Precisão sobre o motivo

A ausência do nome do estabelecimento foi o motivo suficiente e determinante da troca —
não uma entre várias razões equivalentes. A nova fonte também trouxe histórico mensal
(resolvendo uma limitação de um workaround anterior) e dados de contato (telefone,
e-mail), mas esses foram benefícios encontrados durante a validação, não parte da
justificativa original, e o segundo (contato) não é utilizado por nenhuma pergunta do
Canvas.

## Fonte adotada

**"Hospitais e Leitos"** — Ministério da Saúde, mantido pela Coordenação-Geral de Atenção
Hospitalar e Domiciliar (CGHID/DAHU), atualização mensal, licença Creative Commons.
Contém: nome do estabelecimento, razão social, código CNES, gestão, endereço e
quantidade de leitos, com histórico mensal desde 2007.

## Impacto

- **Nenhum impacto** nas perguntas analíticas do Canvas ou no recorte do projeto.
- **Resolve** a limitação de identificação (nome do hospital), antes ausente.
- A fonte **CNES-LT (Leitos por tipo)** é mantida sem alteração — é a única com o
  detalhamento clínico/cirúrgico exigido pela Pergunta 1.
- A fonte **SIH-RD (Internações)** é mantida sem alteração.

## Status

Mudança já implementada e testada no pipeline (coleta automatizada, sem etapa manual).
Documentação técnica completa disponível em `docs/mudanca_fonte_dados_hospitais.md`, no
repositório do projeto.
