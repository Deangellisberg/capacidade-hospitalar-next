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


def coletar_sih(ano: int, mes: int) -> pd.DataFrame:
    df = pysus.sih("PE", ano, mes, group="RD", as_dataframe=True)
    return df


def salvar_bruto(df: pd.DataFrame, ano: int, mes: int, nome_arquivo: str) -> Path:
    #Salva o dado exatamente como veio da fonte, sem nenhuma alteração.

    competencia = f"{ano}{mes:02d}"
    pasta_competencia = PASTA_BRUTOS / competencia
    pasta_competencia.mkdir(parents=True, exist_ok=True)

    caminho = pasta_competencia / f"{nome_arquivo}.parquet"
    df.to_parquet(caminho, index=False)
    return caminho


def main():
    for ano, mes in COMPETENCIAS:
        # --- CNES: Leitos e Estabelecimentos ---
        for grupo in GRUPOS_CNES:
            print(f"Coletando CNES-{grupo} — competência {ano}-{mes:02d}...")
            df = coletar_cnes(ano, mes, grupo)

            if df.empty:
                print(f"  ATENÇÃO: CNES-{grupo} {ano}-{mes:02d} veio vazio. Verificar manualmente.")
                continue

            caminho = salvar_bruto(df, ano, mes, grupo)
            print(f"  OK — {df.shape[0]} linhas, salvo em {caminho}")

        # --- SIH: Internações (RD) ---
        print(f"Coletando SIH-RD — competência {ano}-{mes:02d}...")
        df_sih = coletar_sih(ano, mes)

        if df_sih.empty:
            print(f"  ATENÇÃO: SIH-RD {ano}-{mes:02d} veio vazio. Verificar manualmente.")
        else:
            caminho = salvar_bruto(df_sih, ano, mes, "RD")
            print(f"  OK — {df_sih.shape[0]} linhas, salvo em {caminho}")


if __name__ == "__main__":
    main()