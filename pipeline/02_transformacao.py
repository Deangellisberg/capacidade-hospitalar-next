from pathlib import Path

import pandas as pd
import pyarrow.parquet as pq
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# ------------------------------------------------------------------
#  Lê e concatena arquivos parquet, tolerando colunas ausentes em alguns arquivos.
# ------------------------------------------------------------------
def ler_consolidado(arquivos, colunas):
    if not arquivos:
        return pd.DataFrame(columns=colunas)

    def ler_arquivo(arquivo):
        existentes = pq.read_schema(arquivo).names
        cols = [c for c in colunas if c in existentes]
        return pd.read_parquet(arquivo, columns=cols)

    return (
        pd.concat((ler_arquivo(a) for a in arquivos), ignore_index=True)
        .reindex(columns=colunas)
    )

# ------------------------------------------------------------------
#  Consolida arquivos LT, RD (dados/brutos) e MSHL (dados/brutos/complementares) em DataFrames
# ------------------------------------------------------------------

def consolidar_arquivos_brutos() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]: # type: ignore

    pasta_brutos = Path(__file__).resolve().parents[1] / "dados" / "brutos"
    arquivos_lt = sorted(pasta_brutos.glob("*/LT_recife.parquet"))
    arquivos_rd = sorted(pasta_brutos.glob("*/RD_recife.parquet"))

    pasta_complementar = Path(__file__).resolve().parents[1] / "dados" / "brutos" / "complementares"
    arquivos_mshl = sorted(pasta_complementar.glob("*_recife.parquet"))

    logger.info(f"Consolidando arquivos da pasta: {pasta_brutos}")

    # ------------------------------------------------------------------
    # Lendo os arquivos lt.parquet e concatenando em um DataFrame, apenas com as colunas que nos interessam
    # ------------------------------------------------------------------
    
    lt_colunas = ['COMPETEN', 'CNES', 'CPF_CNPJ', 'CODUFMUN', 'TP_LEITO', 'CODLEITO', 'QT_EXIST', 'QT_SUS']
    df_lt = ler_consolidado(arquivos_lt, lt_colunas)
    logger.info(f"Arquivos LT encontrados: {len(arquivos_lt)}")

    # Ajustando os tipos de dados das colunas do DataFrame LT
    df_lt = df_lt.astype({	
        'COMPETEN': 'string',
        'CNES': 'string',
        'CPF_CNPJ': 'string',
        'CODUFMUN': 'string',
        'TP_LEITO': 'string',
        'CODLEITO': 'string',
        'QT_EXIST': 'Int64',
        'QT_SUS': 'Int64'
    })
    df_lt['CPF_CNPJ'] = df_lt['CPF_CNPJ'].replace('00000000000000', pd.NA)

    # ------------------------------------------------------------------
    # Lendo os arquivos rd.parquet e concatenando em um DataFrame, apenas com as colunas que nos interessam
    # ------------------------------------------------------------------
    rd_colunas = ['UF_ZI', 'ANO_CMPT', 'MES_CMPT', 'ESPEC', 'CGC_HOSP', 'MUNIC_MOV', 'QT_DIARIAS',
                  'DT_INTER', 'DT_SAIDA', 'DIAS_PERM', 'CNES']
    df_rd = ler_consolidado(arquivos_rd, rd_colunas)
    logger.info(f"Arquivos RD encontrados: {len(arquivos_rd)}")

    # Ajustando os tipos de dados das colunas do DataFrame RD
    df_rd = df_rd.astype({
        'UF_ZI': 'string',
        'ANO_CMPT': 'string',
        'MES_CMPT': 'string',
        'ESPEC': 'string',
        'CGC_HOSP': 'string',
        'MUNIC_MOV': 'string', 
        'QT_DIARIAS': 'Int64',
        'DT_INTER': 'string',
        'DT_SAIDA': 'string',
        'DIAS_PERM': 'Int64',
        'CNES': 'string'
    })
    
    # ------------------------------------------------------------------
    # Substituindo valores vazios na coluna CGC_HOSP por NaN
    # ------------------------------------------------------------------
    df_rd['CGC_HOSP'] = df_rd['CGC_HOSP'].replace('', pd.NA)

    # Criando coluna COMPETEN concatenando as colunas ANO_CMPT e MES_CMPT (mesmo padrão da tabela LT),
    # e removendo as colunas ANO_CMPT e MES_CMPT
    df_rd['COMPETEN'] = df_rd['ANO_CMPT'] + df_rd['MES_CMPT']
    df_rd = df_rd.drop(columns=['ANO_CMPT', 'MES_CMPT'])

    # ------------------------------------------------------------------
    # Lendo os arquivos MSHL.parquet e concatenando em um DataFrame, apenas com as colunas que nos interessam
    # ------------------------------------------------------------------
    mshl_colunas = ['COMP', 'CO_IBGE', 'MUNICIPIO', 'CNES', 'NOME_ESTABELECIMENTO', 'RAZAO_SOCIAL', 
                    'LEITOS_EXISTENTES', 'LEITOS_SUS', 'TP_GESTAO'
                    ]

    logger.info(f"Consolidando arquivos da pasta: {pasta_complementar}")
    df_mshl = ler_consolidado(arquivos_mshl, mshl_colunas)
    logger.info(f"Arquivos MSHL encontrados: {len(arquivos_mshl)}")

    # Ajustando os tipos de dados das colunas do DataFrame MSHL
    df_mshl = df_mshl.astype({
        'COMP': 'string',
        'CO_IBGE': 'string',
        'MUNICIPIO': 'string',
        'CNES': 'string',
        'NOME_ESTABELECIMENTO': 'string',
        'RAZAO_SOCIAL': 'string',
        'LEITOS_EXISTENTES': 'Int64',
        'LEITOS_SUS': 'Int64',
        'TP_GESTAO': 'string'
    })

    # Renomeando a coluna COMP para COMPETEN, para manter o mesmo padrão das outras tabelas
    df_mshl = df_mshl.rename(columns={'COMP': 'COMPETEN'})

    return df_lt, df_rd, df_mshl

def main():

    # Consolidar os arquivos brutos em DataFrames
    lt, rd, mshl = consolidar_arquivos_brutos()

    # Salvar os DataFrames consolidados em arquivos parquet na pasta dados/consolidados
    pasta_consolidados = Path(__file__).resolve().parents[1] / "dados" / "consolidados"
    pasta_consolidados.mkdir(parents=True, exist_ok=True)

    lt.to_parquet(pasta_consolidados / "LT_consolidado.parquet", index=False)
    rd.to_parquet(pasta_consolidados / "RD_consolidado.parquet", index=False)
    mshl.to_parquet(pasta_consolidados / "MSHL_consolidado.parquet", index=False)


if __name__ == "__main__":
    main()