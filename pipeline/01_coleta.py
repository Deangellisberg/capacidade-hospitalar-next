"""
pipeline/01_coleta.py

Coleta CNES-LT, SIH-RD e Hospitais/MS para Pernambuco e Recife.

Período: jan/2024 a dez/2026

Saídas:
    dados/brutos/AAAAMM/LT.parquet
    dados/brutos/AAAAMM/LT_recife.parquet
    dados/brutos/AAAAMM/RD.parquet
    dados/brutos/AAAAMM/RD_recife.parquet
    dados/brutos/complementares/hospitais_leitos_ms_{ano}.parquet
    dados/brutos/complementares/hospitais_leitos_ms_{ano}_recife.parquet
"""

import gc
import io
import json
import logging
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

import pandas as pd
import pysus

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


#Configuração

def _competencias(ano_ini, mes_ini, ano_fim, mes_fim):
    #Gera a lista de competências (ano, mes) entre o início e o fim, inclusive.
    if not 1 <= mes_ini <= 12 or not 1 <= mes_fim <= 12:
        raise ValueError("Mês deve estar entre 1 e 12.")
    if (ano_ini, mes_ini) > (ano_fim, mes_fim):
        raise ValueError("Período inicial não pode ser posterior ao final.")

    result = []
    ano, mes = ano_ini, mes_ini
    while (ano, mes) <= (ano_fim, mes_fim):
        result.append((ano, mes))
        mes += 1
        if mes > 12:
            mes = 1
            ano += 1
    return result

COMPETENCIAS = _competencias(2024, 1, 2026, 12)
ANOS_HOSPITAIS = sorted({ano for ano, _ in COMPETENCIAS})

ESTADO = "PE"

RECIFE_IBGE = "261160"

PASTA_BRUTOS = Path("dados/brutos")
PASTA_COMPLEMENTARES = PASTA_BRUTOS / "complementares"


#Fontes: Hospitais e Leitos (Ministério da Saúde)
#URLs confirmadas direto no portal dadosabertos.saude.gov.br.
#O formato mudade ano pra ano (2024 é JSON, 2025/2026 são CSV)

FONTES_HOSPITAIS = {
    2024: {
        "url": "https://s3.sa-east-1.amazonaws.com/ckan.saude.gov.br/Leitos_SUS/json/Leitos_2024.json.zip",
        "formato": "json",
        "coluna_filtro": "MUNICIPIO",
        "valor_filtro": "RECIFE",
    },
    2025: {
        "url": "https://s3.sa-east-1.amazonaws.com/ckan.saude.gov.br/Leitos_SUS/Leitos_csv_2025.zip",
        "formato": "csv",
        "coluna_filtro": "CO_IBGE",
        "valor_filtro": RECIFE_IBGE,
    },
    2026: {
        "url": "https://s3.sa-east-1.amazonaws.com/ckan.saude.gov.br/Leitos_SUS/Leitos_csv_2026.zip",
        "formato": "csv",
        "coluna_filtro": "CO_IBGE",
        "valor_filtro": RECIFE_IBGE,
    },
}


#PySUS
#É utilizado a função legada (pysus.cnes / pysus.sih), não a API nova (pysus.ftp.cnes / pysus.ftp.sih).
#A nova retorna vazio pra Pernambuco nessa versão da biblioteca (2.11.x)

PYSUS_CNES = pysus.cnes
PYSUS_SIH = pysus.sih


#Utilitários

def _normalizar_codigo_municipio(series):
    #Deixa o código do município sempre no mesmo formato (string de 6 dígitos).
    return (
        series
        .astype("string")
        .str.strip()
        .str.replace(r"\.0$", "", regex=True)
        .str.zfill(6)
    )


def _validar_colunas(df, colunas, contexto):
    #Confere se todas as colunas que o código depende existe.
    ausentes = [c for c in colunas if c not in df.columns]
    if ausentes:
        raise ValueError(
            f"{contexto}: faltam as colunas {ausentes}. "
            f"Colunas que vieram: {list(df.columns)}"
        )


def _arquivo_valido(path):
    return path.exists() and path.stat().st_size > 0


def _ja_coletado(pasta, nome):
    return _arquivo_valido(pasta / f"{nome}_recife.parquet")


def _salvar_atomico(df, destino):
    #Salva num arquivo temporário primeiro, e só troca pelo nome final depois de confirmar que gravou certo. 
    #Não vai ser possível salvar um arquivo final incompleto.
    destino.parent.mkdir(parents=True, exist_ok=True)
    temporario = destino.with_suffix(destino.suffix + ".tmp")

    try:
        df.to_parquet(temporario, index=False, compression="snappy")
        if not _arquivo_valido(temporario):
            raise IOError(f"Arquivo temporário vazio: {temporario}")
        temporario.replace(destino)
    finally:
        if temporario.exists():
            temporario.unlink(missing_ok=True)


def _salvar_bruto_e_recife(df, pasta, nome, coluna_municipio, valor_recife):
    #Salva o dado completo e a versão só de Recife. Retorna quantas linhas deram Recife.
    _validar_colunas(df, [coluna_municipio], nome)

    _salvar_atomico(df, pasta / f"{nome}.parquet")

    municipios = _normalizar_codigo_municipio(df[coluna_municipio])
    recife = df.loc[municipios.eq(valor_recife)].copy()
    _salvar_atomico(recife, pasta / f"{nome}_recife.parquet")

    logger.info("%s: bruto=%s | Recife=%s", nome, f"{len(df):,}", f"{len(recife):,}")
    return len(recife)


#Download

def _baixar_buffer(url, tentativas=3, timeout=60):

    ultimo_erro = None

    for tentativa in range(1, tentativas + 1):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "pipeline-saude/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                conteudo = resp.read()

            if not conteudo:
                raise IOError("Servidor retornou conteúdo vazio.")

            logger.info("Download concluído: %.2f MB", len(conteudo) / 1024 / 1024)
            return io.BytesIO(conteudo)

        except (urllib.error.URLError, TimeoutError, OSError, IOError) as exc:
            ultimo_erro = exc
            if tentativa < tentativas:
                espera = 2 ** tentativa
                logger.warning(
                    "Download falhou (tentativa %d/%d): %s. Tentando de novo em %ds.",
                    tentativa, tentativas, exc, espera,
                )
                time.sleep(espera)

    raise RuntimeError(f"Não consegui baixar {url} depois de {tentativas} tentativas: {ultimo_erro}")


def _encontrar_membro(zip_file, extensao):
    membros = [n for n in zip_file.namelist() if n.lower().endswith(f".{extensao.lower()}")]
    if not membros:
        raise FileNotFoundError(f"Nenhum .{extensao} dentro do zip. Tinha: {zip_file.namelist()}")
    if len(membros) > 1:
        logger.warning("Zip tem mais de um .%s — usando o primeiro: %s", extensao, membros[0])
    return membros[0]


def _ler_zip(buffer, formato):
    """Lê CSV ou JSON de dentro de um zip."""
    formato = formato.lower()
    if formato not in {"csv", "json"}:
        raise ValueError(f"Formato não suportado: {formato}")

    with zipfile.ZipFile(buffer) as z:
        nome = _encontrar_membro(z, formato)
        logger.info("Lendo %s", nome)
        with z.open(nome) as f:
            if formato == "csv":
                return pd.read_csv(f, sep=";", encoding="latin-1")
            dados = json.load(f)

    if isinstance(dados, list):
        return pd.DataFrame(dados)
    if isinstance(dados, dict):
        if not dados:
            return pd.DataFrame()
        chave = next(iter(dados))
        valor = dados[chave]
        if not isinstance(valor, list):
            raise ValueError(f"JSON inesperado — chave '{chave}' não é uma lista.")
        return pd.DataFrame(valor)

    raise ValueError(f"Estrutura de JSON que não esperava: {type(dados).__name__}")


#CNES-LT e SIH-RD
def _coletar_pysus(fetcher, nome, ano, mes, coluna_filtro, resultado):
    pasta = PASTA_BRUTOS / f"{ano}{mes:02d}"

    if _ja_coletado(pasta, nome):
        logger.info("%s %04d-%02d: já coletado, pulando.", nome, ano, mes)
        resultado["skipped"] += 1
        return

    try:
        logger.info("Coletando %s %04d-%02d...", nome, ano, mes)
        df = fetcher(ESTADO, ano, mes, group=nome, as_dataframe=True)

        if df is None or df.empty:
            logger.info("%s %04d-%02d: ainda não disponível.", nome, ano, mes)
            resultado["unavailable"] += 1
            return

        qtd_recife = _salvar_bruto_e_recife(df, pasta, nome, coluna_filtro, RECIFE_IBGE)
        if qtd_recife == 0:
            logger.warning("%s %04d-%02d: zero linhas de Recife, vale conferir.", nome, ano, mes)

        resultado["ok"] += 1

    except Exception:
        resultado["errors"] += 1
        logger.exception("Falha coletando %s %04d-%02d.", nome, ano, mes)
    finally:
        gc.collect()


#Hospitais e Leitos (MS)

def _coletar_hospitais_ms(ano, resultado):
    fonte = FONTES_HOSPITAIS.get(ano)
    if fonte is None:
        logger.warning("Hospitais/MS %d: não tenho URL cadastrada pra esse ano.", ano)
        resultado["errors"] += 1
        return

    destino_bruto = PASTA_COMPLEMENTARES / f"hospitais_leitos_ms_{ano}.parquet"
    destino_recife = PASTA_COMPLEMENTARES / f"hospitais_leitos_ms_{ano}_recife.parquet"

    if _arquivo_valido(destino_recife):
        logger.info("Hospitais/MS %d: já coletado, pulando.", ano)
        resultado["skipped"] += 1
        return

    buffer = None
    try:
        logger.info("Coletando Hospitais/MS %d...", ano)
        buffer = _baixar_buffer(fonte["url"])
        df = _ler_zip(buffer, fonte["formato"])

        if df.empty:
            raise ValueError(f"Hospitais/MS {ano}: veio vazio.")

        _validar_colunas(df, [fonte["coluna_filtro"]], f"Hospitais/MS {ano}")
        _salvar_atomico(df, destino_bruto)

        # 2025/2026 filtram por código IBGE; 
        # 2024 não tem esse campo nesse formato, então filtra pelo nome do município mesmo.
        if fonte["coluna_filtro"] == "CO_IBGE":
            mascara = _normalizar_codigo_municipio(df[fonte["coluna_filtro"]]).eq(RECIFE_IBGE)
        else:
            mascara = (
                df[fonte["coluna_filtro"]]
                .astype("string").str.strip().str.upper()
                .eq(fonte["valor_filtro"].upper())
            )

        recife = df.loc[mascara].copy()
        _salvar_atomico(recife, destino_recife)

        logger.info("Hospitais/MS %d: bruto=%s | Recife=%s", ano, f"{len(df):,}", f"{len(recife):,}")
        if recife.empty:
            logger.warning("Hospitais/MS %d: filtro de Recife não achou nada, vale conferir.", ano)

        resultado["ok"] += 1

    except Exception:
        resultado["errors"] += 1
        logger.exception("Falha coletando Hospitais/MS %d.", ano)
    finally:
        if buffer is not None:
            buffer.close()
        gc.collect()


#Execução 

def _log_resumo(resultado):
    logger.info("")
    logger.info("=" * 50)
    logger.info("RESUMO DA COLETA")
    logger.info(
        "OK: %d | Pulados: %d | Indisponíveis: %d | Erros: %d",
        resultado["ok"], resultado["skipped"], resultado["unavailable"], resultado["errors"],
    )
    logger.info("=" * 50)


def main():

    resultado = {"ok": 0, "skipped": 0, "unavailable": 0, "errors": 0}

    inicio, fim = COMPETENCIAS[0], COMPETENCIAS[-1]
    logger.info("=== Pipeline P5 — Coleta ===")
    logger.info("Período: %04d/%02d a %04d/%02d (%d competências)",
                 inicio[0], inicio[1], fim[0], fim[1], len(COMPETENCIAS))

    for ano, mes in COMPETENCIAS:
        logger.info("---- %04d-%02d ----", ano, mes)
        _coletar_pysus(PYSUS_CNES, "LT", ano, mes, "CODUFMUN", resultado)
        _coletar_pysus(PYSUS_SIH, "RD", ano, mes, "MUNIC_MOV", resultado)

    logger.info("")
    logger.info("---- Hospitais e Leitos (MS) ----")
    for ano in ANOS_HOSPITAIS:
        _coletar_hospitais_ms(ano, resultado)

    _log_resumo(resultado)

    if resultado["errors"]:
        logger.error("Coleta terminou com %d erro(s).", resultado["errors"])
        return 1

    logger.info("Coleta finalizada com sucesso.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())