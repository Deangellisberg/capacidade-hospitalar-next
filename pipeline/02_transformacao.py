from pathlib import Path

import pandas as pd

# Constante com o código da cidade do Recife
RECIFE = '261160' 

# ------------------------------------------------------------------
#  Consolida RD.parquet e LT.parquet das subpastas de dados/brutos.
# ------------------------------------------------------------------

def consolidar_arquivos_brutos() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]: # type: ignore

    pasta_brutos = Path(__file__).resolve().parents[1] / "dados" / "brutos"
    arquivos_lt = sorted(pasta_brutos.glob("*/LT.parquet"))
    arquivos_rd = sorted(pasta_brutos.glob("*/RD.parquet"))

    pasta_complementar = Path(__file__).resolve().parents[1] / "dados" / "brutos" / "complementares"
    arquivos_mshl = sorted(pasta_complementar.glob("*.parquet"))

    # ------------------------------------------------
    # Lendo os arquivos lt.parquet e concatenando em um DataFrame, apenas com as colunas que nos interessam
    # ------------------------------------------------
    print (f"Consolidando arquivos da pasta: {pasta_brutos}")
    print (f"Arquivos LT encontrados: {len(arquivos_lt)}")

    lt_colunas = ['COMPETEN', 'CNES', 'CPF_CNPJ', 'CODUFMUN', 'TP_LEITO', 'CODLEITO', 'QT_EXIST', 'QT_SUS']
    df_lt = (
        pd.concat((pd.read_parquet(arquivo, columns=lt_colunas) for arquivo in arquivos_lt), ignore_index=True)
        if arquivos_lt
        else pd.DataFrame()
    )

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

    # Filtrar o dataframe lt para que tenha apenas os registros cujo CODUFMUN seja igual a RECIFE, mantendo o mesmo df (lt)
    df_lt = df_lt[df_lt['CODUFMUN'] == RECIFE].reset_index(drop=True)

    # ------------------------------------------------
    # Lendo os arquivos rd.parquet e concatenando em um DataFrame, apenas com as colunas que nos interessam
    # ------------------------------------------------
    print (f"Arquivos RD encontrados: {len(arquivos_rd)}")
    rd_colunas = ['UF_ZI', 'ANO_CMPT', 'MES_CMPT', 'ESPEC', 'CGC_HOSP', 'MUNIC_MOV']
    df_rd = (
        pd.concat((pd.read_parquet(arquivo, columns=rd_colunas) for arquivo in arquivos_rd), ignore_index=True)
        if arquivos_rd
        else pd.DataFrame()
    )

    # Filtrar o dataframe rd para que tenha apenas os registros cujo MUNIC_MOV seja igual a RECIFE, mantendo o mesmo df (rd)
    df_rd = df_rd[df_rd['MUNIC_MOV'] == RECIFE].reset_index(drop=True)

    # Ajustando os tipos de dados das colunas do DataFrame RD
    df_rd = df_rd.astype({
    'UF_ZI': 'string',
    'ANO_CMPT': 'string',
    'MES_CMPT': 'string',
    'ESPEC': 'string',
    'CGC_HOSP': 'string',
    'MUNIC_MOV': 'string'
    })

    # Criando coluna COMPETEN concatenando as colunas ANO_CMPT e MES_CMPT (mesmo padrão da tabela LT),
    # e removendo as colunas ANO_CMPT e MES_CMPT
    df_rd['COMPETEN'] = df_rd['ANO_CMPT'] + df_rd['MES_CMPT']
    df_rd = df_rd.drop(columns=['ANO_CMPT', 'MES_CMPT'])

    # ------------------------------------------------
    #               A T E N Ç Ã O
    # ------------------------------------------------
    # Numa verificação prévia, detectamos muitos registros com o campo CGC_HOSP vazio (null) na tabela RD, 
    # o que pode afetar a junção com a tabela LT.


    # ------------------------------------------------
    # Lendo os arquivos MSHL.parquet e concatenando em um DataFrame, apenas com as colunas que nos interessam
    # ------------------------------------------------
    mshl_colunas = ['COMP', 'CO_IBGE', 'MUNICIPIO', 'CNES', 'NOME_ESTABELECIMENTO', 'RAZAO_SOCIAL', 'LEITOS_EXISTENTES', 'LEITOS_SUS']

    print (f"Consolidando arquivos MS/hospitais_leitos da pasta: {pasta_complementar}")
    df_mshl = (
        pd.concat((pd.read_parquet(arquivo, columns=mshl_colunas) for arquivo in arquivos_mshl), ignore_index=True)
        if arquivos_mshl
        else pd.DataFrame()
    )
    print (f"Arquivos MSHL encontrados: {len(arquivos_mshl)}")

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

    # Filtrar o dataframe mshl para que tenha apenas os registros cujo CO_IBGE seja igual a RECIFE, mantendo o mesmo df (mshl)
    df_mshl = df_mshl[df_mshl['CO_IBGE'] == RECIFE].reset_index(drop=True)

    return df_lt, df_rd, df_mshl

def main():

    # Consolidar os arquivos LT.parquet e RD.parquet (dados/brutos)
    # e MSHL.parquet (dados/brutos/complementares)
    lt, rd, mshl = consolidar_arquivos_brutos()

    # Salvar os DataFrames consolidados em arquivos parquet na pasta dados/consolidados
    pasta_consolidados = Path(__file__).resolve().parents[1] / "dados" / "consolidados"
    pasta_consolidados.mkdir(parents=True, exist_ok=True)

    lt.to_parquet(pasta_consolidados / "LT_consolidado.parquet", index=False)
    rd.to_parquet(pasta_consolidados / "RD_consolidado.parquet", index=False)
    mshl.to_parquet(pasta_consolidados / "MSHL_consolidado.parquet", index=False)


if __name__ == "__main__":
    main()