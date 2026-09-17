# Domínio oficial — CODLEITO e TP_LEITO (CNES)

Fonte: `SCNES_DOMINIOS.XLS` (dicionário de domínios oficial do CNES, enviado pelo time),
abas `TIPOS DE LEITOS` e `LEITOS`. Este é o de-para definitivo para os campos `TP_LEITO`
e `CODLEITO` usados no CNES-LT.

---

## TP_LEITO — categoria ampla (achado central para a Pergunta 1 do Canvas)

| Código | Categoria |
|---|---|
| **1** | **Cirúrgico** |
| **2** | **Clínico** |
| 3 | Complementar |
| 4 | Obstétricos |
| 5 | Pediátricos |
| 6 | Outras Especialidades |
| 7 | Hospital Dia |

**Para o recorte do projeto ("leitos clínicos e cirúrgicos"): filtrar `TP_LEITO` em `[1, 2]`.**

## CODLEITO — especialidade específica do leito

| Código | Descrição | Código | Descrição |
|---|---|---|---|
| 1 | Buco Maxilo Facial | 47 | Psiquiatria |
| 2 | Cardiologia | 48 | Reabilitação |
| 3 | Cirurgia Geral | 49 | Pneumologia Sanitária |
| 4 | Endocrinologia | 64 | Unidade Intermediária |
| 5 | Gastroenterologia | 65 | Unidade Intermediária Neonatal |
| 6 | Ginecologia | 66 | Unidade Isolamento |
| 7 | Cirúrgico/Diagnóstico/Terapêutico | 67 | Transplante |
| 8 | Nefrologia/Urologia | 68 | Pediatria Cirúrgica |
| 9 | Neurocirurgia | 69 | AIDS |
| 10 | Obstetrícia Cirúrgica | 70 | Fibrose Cística |
| 11 | Oftalmologia | 71 | Intercorrência Pós-Transplante |
| 12 | Oncologia | 72 | Geriatria |
| 13 | Ortopedia/Traumatologia | 73 | Saúde Mental |
| 14 | Otorrinolaringologia | 74 | UTI Adulto - Tipo I |
| 15 | Plástica | 75 | UTI Adulto - Tipo II |
| 16 | Torácica | 76 | UTI Adulto - Tipo III |
| 31 | AIDS | 77 | UTI Pediátrica - Tipo I |
| 32 | Cardiologia | 78 | UTI Pediátrica - Tipo II |
| 33 | Clínica Geral | 79 | UTI Pediátrica - Tipo III |
| 34 | Crônicos | 80 | UTI Neonatal - Tipo I |
| 35 | Dermatologia | 81 | UTI Neonatal - Tipo II |
| 36 | Geriatria | 82 | UTI Neonatal - Tipo III |
| 37 | Hansenologia | 83 | UTI de Queimados |
| 38 | Hematologia | 84 | Acolhimento Noturno |
| 40 | Nefrourologia | 85 | UTI Coronariana Tipo II (UCO Tipo II) |
| 41 | Neonatologia | 86 | UTI Coronariana Tipo III (UCO Tipo III) |
| 42 | Neurologia | 87 | Saúde Mental |
| 43 | Obstetrícia Clínica | 88 | Queimado Adulto |
| 44 | Oncologia | 89 | Queimado Pediátrico |
| 45 | Pediatria Clínica | 90 | Queimado Adulto |
| 46 | Pneumologia | 91 | Queimado Pediátrico |
| | | 92 | Unidade de Cuidados Intermediários Neonatal Convencional |
| | | 93 | Unidade de Cuidados Intermediários Neonatal Canguru |
| | | 94 | Unidade de Cuidados Intermediários Pediátrico |
| | | 95 | Unidade de Cuidados Intermediários Adulto |

**Padrão observado:** os códigos 1–16 correspondem majoritariamente a especialidades
cirúrgicas (`TP_LEITO=1`), os códigos 31–49 a especialidades clínicas (`TP_LEITO=2`) —
mas o filtro correto para o pipeline é sempre pelo campo `TP_LEITO` diretamente, não por
inferir a partir da faixa numérica do `CODLEITO`.
