from pathlib import Path

import pandas as pd
import logging
import pyarrow.parquet as pq

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

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
    df_lt = (
        pd.concat((pd.read_parquet(arquivo, columns=lt_colunas) for arquivo in arquivos_lt), ignore_index=True)
        if arquivos_lt
        else pd.DataFrame()
    )
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
    rd_colunas = ['UF_ZI', 'ANO_CMPT', 'MES_CMPT', 'ESPEC', 'CGC_HOSP', 'MUNIC_MOV']
    df_rd = (
        pd.concat((pd.read_parquet(arquivo, columns=rd_colunas) for arquivo in arquivos_rd), ignore_index=True)
        if arquivos_rd
        else pd.DataFrame()
    )

    logger.info(f"Arquivos RD encontrados: {len(arquivos_rd)}")

    # Ajustando os tipos de dados das colunas do DataFrame RD
    df_rd = df_rd.astype({
    'UF_ZI': 'string',
    'ANO_CMPT': 'string',
    'MES_CMPT': 'string',
    'ESPEC': 'string',
    'CGC_HOSP': 'string',
    'MUNIC_MOV': 'string'
    })
    
    # ------------------------------------------------------------------
    #               A T E N Ç Ã O
    # ------------------------------------------------------------------
    # Numa verificação prévia, detectamos muitos registros com o campo CGC_HOSP vazio (null) na tabela RD, 
    # o que pode afetar a junção com a tabela LT.


    df_rd['CGC_HOSP'] = df_rd['CGC_HOSP'].replace('', pd.NA)

    # Criando coluna COMPETEN concatenando as colunas ANO_CMPT e MES_CMPT (mesmo padrão da tabela LT),
    # e removendo as colunas ANO_CMPT e MES_CMPT
    df_rd['COMPETEN'] = df_rd['ANO_CMPT'] + df_rd['MES_CMPT']
    df_rd = df_rd.drop(columns=['ANO_CMPT', 'MES_CMPT'])

    # ------------------------------------------------------------------
    # Lendo os arquivos MSHL.parquet e concatenando em um DataFrame, apenas com as colunas que nos interessam
    # ------------------------------------------------------------------
    mshl_colunas = ['COMP', 'CO_IBGE', 'MUNICIPIO', 'CNES', 'NOME_ESTABELECIMENTO', 'RAZAO_SOCIAL', 'LEITOS_EXISTENTES', 'LEITOS_SUS']

    logger.info(f"Consolidando arquivos da pasta: {pasta_complementar}")
    # df_mshl = (
    #     pd.concat((pd.read_parquet(arquivo, columns=mshl_colunas) for arquivo in arquivos_mshl), ignore_index=True)
    #     if arquivos_mshl
    #     else pd.DataFrame()
    # )
    def ler_mshl(arquivo):
        existentes = pq.read_schema(arquivo).names
        return pd.read_parquet(arquivo, columns=[c for c in mshl_colunas if c in existentes])

    df_mshl = (
        pd.concat((ler_mshl(a) for a in arquivos_mshl), ignore_index=True)
        .reindex(columns=mshl_colunas)
        if arquivos_mshl
        else pd.DataFrame(columns=mshl_colunas)
    )
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
        'LEITOS_SUS': 'Int64'
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