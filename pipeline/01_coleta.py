"""
Coleta dos dados de CNES (Leitos e Estabelecimentos) via PySUS, para o recorte
do projeto: Pernambuco, competências jul/2024 a jun/2026.
"""

import pysus
import pandas as pd
from pathlib import Path

# Recorte de competências. Começamos com 1 só, pra validar antes de escalar
COMPETENCIAS = [
    (2026, 6),
]

GRUPOS_CNES = ["LT", "ST"]  # Leitos e Estabelecimentos
PASTA_BRUTOS = Path("dados/brutos")

def coletar_cnes(ano: int, mes: int, grupo: str) -> pd.DataFrame:
    # Baixa um grupo do CNES (LT ou ST) para PE, numa competência específica.
    df = pysus.cnes("PE", ano, mes, group=grupo, as_dataframe=True)
    return df

def salvar_bruto(df: pd.DataFrame, ano: int, mes: int, grupo: str) -> Path:
    #Salva o dado exatamente como veio da fonte, sem nenhuma alteração.

    competencia = f"{ano}{mes:02d}"
    pasta_competencia = PASTA_BRUTOS / competencia
    pasta_competencia.mkdir(parents=True, exist_ok=True)

    caminho = pasta_competencia / f"{grupo}.parquet"
    df.to_parquet(caminho, index=False)
    return caminho

def main():
    for ano, mes in COMPETENCIAS:
        for grupo in GRUPOS_CNES:
            print(f"Coletando {grupo} — competência {ano}-{mes:02d}...")
            df = coletar_cnes(ano, mes, grupo)

            if df.empty:
                print(f"  ATENÇÃO: {grupo} {ano}-{mes:02d} veio vazio. Verificar manualmente.")
                continue

            caminho = salvar_bruto(df, ano, mes, grupo)
            print(f"  OK — {df.shape[0]} linhas, salvo em {caminho}")


if __name__ == "__main__":
    main()