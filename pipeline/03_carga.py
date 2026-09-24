"""
pipeline/03_carga.py

Carrega os consolidados de dados/consolidados/ no Postgres,
seguindo o modelo de 01_schema.sql.

Entradas:
    dados/consolidados/LT_consolidado.parquet    -> fato_leitos
    dados/consolidados/RD_consolidado.parquet    -> fato_internacoes
    dados/consolidados/MSHL_consolidado.parquet  -> dim_estabelecimento

Conexão:
    DATABASE_URL (postgresql://usuario:senha@host:5432/banco)
    ou as variáveis padrão do libpq: PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD.

Uso:
    python pipeline/03_carga.py                  # carga completa
    python pipeline/03_carga.py --dry-run        # roda tudo e desfaz no final (rollback)
    python pipeline/03_carga.py --schema caminho/01_schema.sql

A carga é idempotente: pode rodar de novo sem duplicar (upsert pela chave primária).
Tudo acontece em uma única transação: se algo falhar, nada é gravado.
"""

import argparse
import io
import logging
import os
from pathlib import Path

import pandas as pd
import psycopg2

from dotenv import load_dotenv
load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


# Configuração

RAIZ = Path(__file__).resolve().parents[1]
PASTA_CONSOLIDADOS = RAIZ / "dados" / "consolidados"
PASTA_REJEITADOS = RAIZ / "dados" / "rejeitados"
SCHEMA_PADRAO = Path(__file__).resolve().parents[1] / "sql/01_schema.sql"

ARQUIVOS = {
    "lt": PASTA_CONSOLIDADOS / "LT_consolidado.parquet",
    "rd": PASTA_CONSOLIDADOS / "RD_consolidado.parquet",
    "mshl": PASTA_CONSOLIDADOS / "MSHL_consolidado.parquet",
}

PK_DIM = ["cnes", "competencia"]
PK_LEITOS = ["cnes", "codleito", "competencia"]
PK_INTERNACOES = ["n_aih", "competencia", "ident"]


# Utilitários de limpeza

def _texto(serie):
    #String sem espaços nas pontas; vazio vira nulo.
    s = serie.astype("string").str.strip()
    return s.mask(s.eq(""), pd.NA)


def _codigo(serie, tamanho=None):
    #Código como texto: tira ".0" (float que virou string) e completa zeros à esquerda.
    s = _texto(serie).str.replace(r"\.0$", "", regex=True)
    return s.str.zfill(tamanho) if tamanho else s


def _competencia(serie):
    #Garante AAAAMM (6 dígitos). Se vier em outro formato, para com erro claro.
    s = _texto(serie).str.replace(r"\D", "", regex=True)
    invalidas = s.notna() & s.str.len().ne(6)
    if invalidas.any():
        exemplos = serie[invalidas].drop_duplicates().head(5).tolist()
        raise ValueError(f"Competência fora do formato AAAAMM. Exemplos: {exemplos}")
    return s


def _inteiro(serie):
    return pd.to_numeric(serie, errors="coerce").astype("Int64")


def _sem_chave_nula(df, chaves, tabela):
    ok = df[chaves].notna().all(axis=1)
    if not ok.all():
        logger.warning("%s: %s linha(s) sem chave (%s) descartadas.",
                       tabela, f"{(~ok).sum():,}", ", ".join(chaves))
    return df[ok]


def _checar_tamanhos(df, limites, tabela):
    #Evita erro genérico do Postgres ("value too long") apontando a coluna e um exemplo.
    for coluna, limite in limites.items():
        excedem = df[coluna].str.len().gt(limite)
        if excedem.any():
            raise ValueError(
                f"{tabela}.{coluna}: {int(excedem.sum())} valor(es) com mais de {limite} "
                f"caracteres. Exemplo: {df.loc[excedem, coluna].iloc[0]!r}"
            )


def _separar_orfaos(df, coluna, validos, tabela):
    #Separa linhas cuja FK não existe na tabela de domínio. Nulo passa (FK nullable).
    ok = df[coluna].isna() | df[coluna].isin(list(validos))
    orfaos = df[~ok]
    if not orfaos.empty:
        resumo = orfaos[coluna].value_counts().head(10).to_dict()
        PASTA_REJEITADOS.mkdir(parents=True, exist_ok=True)
        destino = PASTA_REJEITADOS / f"{tabela}_{coluna}_sem_dominio.csv"
        orfaos.to_csv(destino, index=False)
        logger.warning(
            "%s: %s linha(s) com %s fora do domínio, não carregadas (salvas em %s). "
            "Mais frequentes: %s",
            tabela, f"{len(orfaos):,}", coluna, destino, resumo,
        )
    return df[ok]


# Preparação dos dados

def preparar_dim_estabelecimento(df):
    out = pd.DataFrame({
        "cnes": _codigo(df["CNES"], 7),
        "competencia": _competencia(df["COMPETEN"]),
        "nome_estabelecimento": _texto(df["NOME_ESTABELECIMENTO"]),
        "razao_social": _texto(df["RAZAO_SOCIAL"]),
        "tp_gestao": _texto(df["TP_GESTAO"]),
        "co_ibge": _codigo(df["CO_IBGE"]),
        "municipio": _texto(df["MUNICIPIO"]),
        "leitos_existentes": _inteiro(df["LEITOS_EXISTENTES"]),
        "leitos_sus": _inteiro(df["LEITOS_SUS"]),
    })
    out = _sem_chave_nula(out, PK_DIM, "dim_estabelecimento")

    n_dup = int(out.duplicated(PK_DIM).sum())
    if n_dup:
        logger.warning("dim_estabelecimento: %s chave(s) repetida(s); mantida a última.", f"{n_dup:,}")
        out = out.drop_duplicates(PK_DIM, keep="last")

    _checar_tamanhos(out, {
        "nome_estabelecimento": 200, "razao_social": 200, "tp_gestao": 1,
        "co_ibge": 7, "municipio": 100,
    }, "dim_estabelecimento")
    return out.reset_index(drop=True)


def preparar_fato_leitos(df):
    out = pd.DataFrame({
        "cnes": _codigo(df["CNES"], 7),
        "codleito": _codigo(df["CODLEITO"], 2),
        "tp_leito": _codigo(df["TP_LEITO"]),
        "competencia": _competencia(df["COMPETEN"]),
        "qt_exist": _inteiro(df["QT_EXIST"]),
        "qt_sus": _inteiro(df["QT_SUS"]),
    })
    out = _sem_chave_nula(out, PK_LEITOS, "fato_leitos")

    # Linha 100% repetida é duplicidade de coleta: descarta.
    # Mesma chave com valores diferentes: soma as quantidades e avisa.
    out = out.drop_duplicates()
    n_dup = int(out.duplicated(PK_LEITOS).sum())
    if n_dup:
        logger.warning("fato_leitos: %s chave(s) repetida(s) com valores diferentes; "
                       "quantidades somadas.", f"{n_dup:,}")
        out = out.groupby(PK_LEITOS, as_index=False).agg(
            tp_leito=("tp_leito", "first"),
            qt_exist=("qt_exist", "sum"),
            qt_sus=("qt_sus", "sum"),
        )

    _checar_tamanhos(out, {"cnes": 7, "codleito": 2, "tp_leito": 2}, "fato_leitos")
    return out[["cnes", "codleito", "tp_leito", "competencia", "qt_exist", "qt_sus"]].reset_index(drop=True)


def preparar_fato_internacoes(df):
    mapa = {
        "N_AIH": "n_aih", "COMPETEN": "competencia", "CNES": "cnes", "CGC_HOSP": "cgc_hosp",
        "ESPEC": "espec", "IDENT": "ident", "SEQUENCIA": "sequencia",
        "DT_INTER": "dt_inter", "DT_SAIDA": "dt_saida", "DIAS_PERM": "dias_perm",
        "QT_DIARIAS": "qt_diarias", "PROC_REA": "proc_rea", "MUNIC_RES": "munic_res",
        "MUNIC_MOV": "munic_mov", "UF_ZI": "uf_zi", "IDADE": "idade",
        "SEXO": "sexo", "MORTE": "morte",
    }
    out = df[list(mapa)].rename(columns=mapa).copy()

    for c in ["n_aih", "cgc_hosp", "sequencia", "proc_rea", "munic_res", "munic_mov",
              "uf_zi", "sexo", "morte"]:
        out[c] = _texto(out[c])
    out["cnes"] = _codigo(out["cnes"], 7)
    out["espec"] = _codigo(out["espec"], 2)
    out["ident"] = _codigo(out["ident"])
    out["competencia"] = _competencia(out["competencia"])
    for c in ["dias_perm", "qt_diarias", "idade"]:
        out[c] = _inteiro(out[c])
    for c in ["dt_inter", "dt_saida"]:
        out[c] = pd.to_datetime(out[c], errors="coerce")

    out = _sem_chave_nula(out, PK_INTERNACOES, "fato_internacoes")

    # Chave repetida: mantém a linha de maior sequencia (desempate).
    n_dup = int(out.duplicated(PK_INTERNACOES).sum())
    if n_dup:
        logger.warning("fato_internacoes: %s chave(s) repetida(s); mantida a de maior sequencia.",
                       f"{n_dup:,}")
        out = (out.sort_values("sequencia", na_position="first")
                  .drop_duplicates(PK_INTERNACOES, keep="last"))

    _checar_tamanhos(out, {
        "n_aih": 20, "cnes": 7, "cgc_hosp": 14, "espec": 2, "ident": 1, "sequencia": 5,
        "proc_rea": 10, "munic_res": 7, "munic_mov": 7, "uf_zi": 7, "sexo": 1, "morte": 1,
    }, "fato_internacoes")
    return out[list(mapa.values())].reset_index(drop=True)


# Banco

def garantir_schema(cur, caminho):
    #Cria o schema só se ainda não existir (o .sql não tem IF NOT EXISTS).
    cur.execute("SELECT to_regclass('fato_leitos')")
    if cur.fetchone()[0] is not None:
        logger.info("Schema já existe, não vou recriar.")
        return
    if not caminho.exists():
        raise FileNotFoundError(f"Schema não encontrado: {caminho}")
    logger.info("Criando schema a partir de %s", caminho)
    cur.execute(caminho.read_text(encoding="utf-8"))


def _dominio(cur, tabela, coluna):
    cur.execute(f"SELECT {coluna} FROM {tabela}")
    return {str(linha[0]).strip() for linha in cur.fetchall()}


def _upsert(cur, tabela, df, pk):
    #COPY para uma tabela temporária + INSERT ... ON CONFLICT DO UPDATE.
    if df.empty:
        logger.warning("%s: nada para carregar.", tabela)
        return 0

    colunas = list(df.columns)
    lista = ", ".join(colunas)
    stg = f"stg_{tabela}"

    cur.execute(f"CREATE TEMP TABLE {stg} (LIKE {tabela} INCLUDING DEFAULTS) ON COMMIT DROP")

    buffer = io.StringIO()
    df.to_csv(buffer, index=False, header=False, date_format="%Y-%m-%d")
    buffer.seek(0)
    cur.copy_expert(f"COPY {stg} ({lista}) FROM STDIN WITH (FORMAT csv)", buffer)

    atualizar = [c for c in colunas if c not in pk]
    if atualizar:
        acao = "DO UPDATE SET " + ", ".join(f"{c} = EXCLUDED.{c}" for c in atualizar)
    else:
        acao = "DO NOTHING"

    cur.execute(
        f"INSERT INTO {tabela} ({lista}) SELECT {lista} FROM {stg} "
        f"ON CONFLICT ({', '.join(pk)}) {acao}"
    )
    logger.info("%s: %s linha(s) inseridas/atualizadas.", tabela, f"{cur.rowcount:,}")
    return cur.rowcount


def _resumo(cur):
    logger.info("=" * 50)
    logger.info("LINHAS NO BANCO")
    for tabela in ["dim_estabelecimento", "fato_leitos", "fato_internacoes"]:
        cur.execute(f"SELECT count(*) FROM {tabela}")
        logger.info("%-22s %s", tabela, f"{cur.fetchone()[0]:,}")
    logger.info("=" * 50)


# Execução

def main():
    parser = argparse.ArgumentParser(description="Carga dos consolidados no Postgres.")
    parser.add_argument("--schema", type=Path, default=SCHEMA_PADRAO, help="Caminho do 01_schema.sql")
    parser.add_argument("--dry-run", action="store_true", help="Executa tudo e desfaz no final")
    args = parser.parse_args()

    faltando = [str(p) for p in ARQUIVOS.values() if not p.exists()]
    if faltando:
        logger.error("Rode o 02_transformacao.py antes. Arquivos não encontrados: %s", faltando)
        return 1

    logger.info("=== Pipeline P5 — Carga ===")
    lt = pd.read_parquet(ARQUIVOS["lt"])
    rd = pd.read_parquet(ARQUIVOS["rd"])
    mshl = pd.read_parquet(ARQUIVOS["mshl"])
    logger.info("Lidos: LT=%s | RD=%s | MSHL=%s", f"{len(lt):,}", f"{len(rd):,}", f"{len(mshl):,}")

    conn = psycopg2.connect(os.environ.get("DATABASE_URL"))
    try:
        with conn.cursor() as cur:
            garantir_schema(cur, args.schema)

            # Dimensão primeiro, fatos depois (mesma lógica do schema)
            dim = preparar_dim_estabelecimento(mshl)
            _upsert(cur, "dim_estabelecimento", dim, PK_DIM)

            leitos = preparar_fato_leitos(lt)
            leitos = _separar_orfaos(leitos, "codleito", _dominio(cur, "dom_codigo_leito", "codleito"), "fato_leitos")
            leitos = _separar_orfaos(leitos, "tp_leito", _dominio(cur, "dom_tipo_leito", "tp_leito"), "fato_leitos")
            _upsert(cur, "fato_leitos", leitos, PK_LEITOS)

            internacoes = preparar_fato_internacoes(rd)
            internacoes = _separar_orfaos(internacoes, "espec", _dominio(cur, "dom_especialidade_sih", "espec"), "fato_internacoes")
            internacoes = _separar_orfaos(internacoes, "ident", _dominio(cur, "dom_tipo_aih", "ident"), "fato_internacoes")
            _upsert(cur, "fato_internacoes", internacoes, PK_INTERNACOES)

            _resumo(cur)

        if args.dry_run:
            conn.rollback()
            logger.info("Dry-run: nada foi gravado (rollback).")
        else:
            conn.commit()
            logger.info("Carga finalizada com sucesso.")
        return 0

    except Exception:
        conn.rollback()
        logger.exception("Carga falhou; nada foi gravado.")
        return 1
    finally:
        conn.close()


if __name__ == "__main__":
    raise SystemExit(main())
