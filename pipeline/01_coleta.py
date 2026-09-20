"""
Coleta dos dados de CNES (Leitos), SIH (Internações) e Hospitais/Leitos (nome
e identificação dos hospitais) via PySUS e download direto do Ministério da
Saúde. Recorte: Pernambuco/Recife, competências jul/2024 a jun/2026.
"""

import urllib.request
import zipfile
import pysus
import pandas as pd
from pathlib import Path

# expandir para as 24 competências do Canvas (jul/2024 a jun/2026).
COMPETENCIAS = [
    (2024, 7),
]

# Anos necessários para cobrir jul/2024–jun/2026 na fonte "Hospitais e Leitos"
ANOS_HOSPITAIS = [2024, 2025, 2026]

PASTA_BRUTOS = Path("dados/brutos")
PASTA_COMPLEMENTARES = PASTA_BRUTOS / "complementares"

URL_HOSPITAIS_BASE = "https://s3.sa-east-1.amazonaws.com/ckan.saude.gov.br/Leitos_SUS/Leitos_csv_{ano}.zip"


def coletar_cnes_lt(ano: int, mes: int) -> pd.DataFrame:
    # Baixa o grupo LT (Leitos) do CNES para PE.
    df = pysus.cnes("PE", ano, mes, group="LT", as_dataframe=True)
    return df # pyright: ignore[reportReturnType]


def coletar_sih(ano: int, mes: int) -> pd.DataFrame:
    df = pysus.sih("PE", ano, mes, group="RD", as_dataframe=True)
    return df # pyright: ignore[reportReturnType]


def coletar_hospitais_ms(ano: int) -> pd.DataFrame:
    #Baixa o arquivo anual "Hospitais e Leitos" do Ministério da Saúde (dados nacionais)
    url = URL_HOSPITAIS_BASE.format(ano=ano)
    zip_path = PASTA_COMPLEMENTARES / f"temp_leitos_{ano}.zip"
    PASTA_COMPLEMENTARES.mkdir(parents=True, exist_ok=True)

    urllib.request.urlretrieve(url, zip_path)

    with zipfile.ZipFile(zip_path) as z:
        nomes_csv = [n for n in z.namelist() if n.endswith(".csv")]
        if not nomes_csv:
            raise ValueError(f"Nenhum CSV encontrado dentro de {zip_path}")
        with z.open(nomes_csv[0]) as f:
            df = pd.read_csv(f, sep=";", encoding="latin-1")

    zip_path.unlink()  # remove o .zip depois de extrair — não versionar dado bruto temporário
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
    # --- CNES-LT e SIH-RD: por competência ---
    for ano, mes in COMPETENCIAS:
        print(f"Coletando CNES-LT — competência {ano}-{mes:02d}...")
        df_lt = coletar_cnes_lt(ano, mes)
        if df_lt.empty:
            print(f"  ATENÇÃO: CNES-LT {ano}-{mes:02d} veio vazio. Verificar manualmente.")
        else:
            caminho = salvar_bruto(df_lt, ano, mes, "LT")
            print(f"  OK — {df_lt.shape[0]} linhas, salvo em {caminho}")

        print(f"Coletando SIH-RD — competência {ano}-{mes:02d}...")
        df_sih = coletar_sih(ano, mes)
        if df_sih.empty:
            print(f"  ATENÇÃO: SIH-RD {ano}-{mes:02d} veio vazio. Verificar manualmente.")
        else:
            caminho = salvar_bruto(df_sih, ano, mes, "RD")
            print(f"  OK — {df_sih.shape[0]} linhas, salvo em {caminho}")

    # --- Hospitais e Leitos (MS): por ano, não por competência ---
    for ano in ANOS_HOSPITAIS:
        print(f"Coletando Hospitais e Leitos (MS) — ano {ano}...")
        try:
            df_hosp = coletar_hospitais_ms(ano)
        except Exception as e:
            print(f"  ATENÇÃO: falha ao coletar ano {ano}: {e}")
            continue

        if df_hosp.empty:
            print(f"  ATENÇÃO: Hospitais e Leitos {ano} veio vazio. Verificar manualmente.")
            continue

        PASTA_COMPLEMENTARES.mkdir(parents=True, exist_ok=True)
        caminho = PASTA_COMPLEMENTARES / f"hospitais_leitos_ms_{ano}.parquet"
        df_hosp.to_parquet(caminho, index=False)
        print(f"  OK — {df_hosp.shape[0]} linhas, salvo em {caminho}")


if __name__ == "__main__":
    main()