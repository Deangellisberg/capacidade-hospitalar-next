# Painel de Capacidade Hospitalar — Unidades de Gestão Própria (Recife)

## Ideia do visual

O painel é organizado em **4 abas**, seguindo uma narrativa de **causa → efeito → ação**: cada aba responde uma pergunta diferente que orienta a tomada de decisão sobre investimento e contratualização.

```
1. Cenário Geral        →  "Como está a rede como um todo?"
2. Cadastro x Produção   →  "Onde está o problema?"        (efeito)
3. Permanência e Especialidades → "Por que está acontecendo?" (causa)
4. Investimento          →  "O que fazer, e onde?"         (ação)
```

A aba 1 funciona como resumo executivo — reúne os KPIs principais, o mapa das unidades e a evolução da ocupação, de forma que quem abre só essa aba já sai com o essencial. As abas 2 a 4 são o aprofundamento, para quem quer investigar uma unidade ou especialidade específica.

## Estrutura das abas

### 1. Cenário Geral
Visão executiva da rede: KPIs principais (total de saídas, ocupação média sobre cadastrados e sobre operacionais, TMP médio), mapa das unidades por farol de ocupação e gráfico de evolução mensal (24 meses).

### 2. Cadastro (capacidade) x Produção (uso real)
Cruza o que está registrado no papel com o que foi efetivamente usado, para identificar leitos que rendem pouco e hospitais sobrecarregados. Traz a matriz por hospital, o farol/gauge operacional e o cruzamento de ocupação por tipo de leito e especialidade (para achar a "ociosidade invisível").

### 3. Permanência e Especialidades
Investiga o tempo médio de permanência (TMP) por especialidade e o censo diário/pacientes-dia, para identificar desvios — leitos usados fora da especialidade original ou permanências fora do padrão.

### 4. Investimento
Conclusão do painel: cruza o gap entre ocupação cadastrada e operacional para apontar o tipo de investimento necessário (expansão física, manutenção/custeio, pessoal ou readequação de perfil assistencial), com uma matriz de diagnóstico e metas contratuais sugeridas por unidade.

## Filtros

O painel tem 4 filtros, divididos em dois grupos por escopo:

- **Globais** (valem em todas as abas): **Período** e **Unidade** — toda aba usa essas duas dimensões, inclusive o mapa e os KPIs da aba 1.
- **Contextuais** (escopo configurado por página no Looker Studio, ativos só nas abas 2 e 3): **Tipo de leito** e **Especialidade** — são as únicas abas que quebram os dados por esse recorte; nas abas 1 e 4 eles não teriam o que filtrar.

## Avisos fixos (presentes em todas as abas)

- **Farol de ocupação** — legenda de cores: `< 70%` ocioso, `71–85%` saudável, `> 85%` sobrecarga.
- **Nota metodológica** — taxa calculada sobre leitos cadastrados (SUS/CNES); pode divergir de sistemas com leitos operacionais, como a SERMAC.
- **Natureza do painel** — retrospectivo (24 meses), voltado a planejamento de investimento, não a monitoramento em tempo real.

## Por que 4 abas e não 2

Juntar as abas comprometeria a separação da narrativa: misturar "Cadastro x Produção" com "Permanência e Especialidades" juntaria tipos de gráfico muito diferentes (matriz, gauge, heatmap, barras de TMP) numa mesma tela e confundiria o diagnóstico (onde) com a causa (por quê). Já juntar "Geral" com "Investimento" colocaria a conclusão do painel junto do resumo executivo, antes de a pessoa ver o diagnóstico.

## Ferramenta

**Looker Studio**, conectado ao PostgreSQL (tabela `tb_censo_mensal_looker`). Gratuito, multiplataforma e alinhado ao desenho técnico já definido para o pipeline (views agregadas por mês, campos calculados de farol e diagnóstico).
