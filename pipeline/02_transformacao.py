from pathlib import Path

import pandas as pd

RECIFE = '261160' # Constante com o código da cidade do Recife

# ------------------------------------------------------------------
#  Consolida RD.parquet e LT.parquet das subpastas de dados/brutos.
# ------------------------------------------------------------------

def consolidar_arquivos_brutos() -> tuple[pd.DataFrame, pd.DataFrame]:
	
	pasta_brutos = Path(__file__).resolve().parents[1] / "dados" / "brutos"
	arquivos_rd = sorted(pasta_brutos.glob("*/RD.parquet"))
	arquivos_lt = sorted(pasta_brutos.glob("*/LT.parquet"))

	df_rd = (
		pd.concat((pd.read_parquet(arquivo) for arquivo in arquivos_rd), ignore_index=True)
		if arquivos_rd
		else pd.DataFrame()
	)
	df_lt = (
		pd.concat((pd.read_parquet(arquivo) for arquivo in arquivos_lt), ignore_index=True)
		if arquivos_lt
		else pd.DataFrame()
	)

	return df_rd, df_lt

def main():

    # Consolidar os arquivos RD.parquet e LT.parquet das subpastas de dados/brutos
    _, lt = consolidar_arquivos_brutos()

    # Padroniza os tipos de dados das colunas do DataFrame LT
    lt = lt.astype({
        'CNES': 'string',
        'CODUFMUN': 'string',
        'TP_LEITO': 'string',
        'CODLEITO': 'string',
        'QT_EXIST': 'Int64',
        'QT_SUS': 'Int64',
        'COMPETEN': 'string'
    })

    # Filtra apenas os registros do município de Recife (CODUFMUN = 2611606)
    lt = lt[lt['CODUFMUN'] == RECIFE].reset_index(drop=True)


if __name__ == "__main__":
    main()