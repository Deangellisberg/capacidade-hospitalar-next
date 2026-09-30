import os
from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional, Tuple

import psycopg2
from dotenv import load_dotenv

load_dotenv()


class ConexaoBase(ABC):
    """Contrato abstrato de conexão e operações básicas de banco de dados."""

    def __init__(self, **kwargs):
        self.conn = None
        self.kwargs = kwargs or self._default_kwargs()

    @staticmethod
    def _default_kwargs() -> Dict[str, Any]:
        database_url = os.getenv("DATABASE_URL")
        if database_url:
            return {"database_url": database_url}

        return {
            "host": os.getenv("DB_HOST", "localhost"),
            "port": os.getenv("DB_PORT", "5432"),
            "dbname": os.getenv("DB_NAME"),
            "user": os.getenv("DB_USER"),
            "password": os.getenv("DB_PASSWORD"),
        }

    @abstractmethod
    def conectar(self):
        """Abre uma conexão ativa com o banco."""
        raise NotImplementedError

    @abstractmethod
    def fechar(self):
        """Fecha a conexão ativa, se existir."""
        raise NotImplementedError

    @abstractmethod
    def executar(self, query: str, params: Optional[Tuple] = None) -> int:
        """Executa uma instrução DML/DDL SQL e faz commit, retornando o número de linhas afetadas."""
        raise NotImplementedError

    @abstractmethod
    def consultar(self, query: str, params: Optional[Tuple] = None) -> List[Tuple]:
        """Executa uma consulta SQL e retorna todas as linhas do resultado."""
        raise NotImplementedError

    @abstractmethod
    def testar(self) -> bool:
        """Valida se a conexão com o banco está ativa."""
        raise NotImplementedError

    def __enter__(self):
        self.conectar()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.fechar()
        return False


class Conexao(ConexaoBase):
    """Implementação concreta de conexão PostgreSQL utilizando psycopg2."""

    def conectar(self):
        if self.conn is not None and getattr(self.conn, "closed", 0) == 0:
            return self.conn

        self.conn = conectar(**self.kwargs)
        return self.conn

    def fechar(self):
        if self.conn is not None:
            fechar_conexao(self.conn)
            self.conn = None

    def executar(self, query: str, params: Optional[Tuple] = None) -> int:
        if self.conn is None or self.conn.closed:
            self.conectar()

        try:
            with self.conn.cursor() as cursor:
                cursor.execute(query, params)
                rowcount = cursor.rowcount
            self.conn.commit()
            return rowcount
        except Exception:
            self.conn.rollback()
            raise

    def consultar(self, query: str, params: Optional[Tuple] = None) -> List[Tuple]:
        if self.conn is None or self.conn.closed:
            self.conectar()

        with self.conn.cursor() as cursor:
            cursor.execute(query, params)
            return cursor.fetchall()

    def testar(self) -> bool:
        try:
            if self.conn is None or self.conn.closed:
                self.conectar()

            with self.conn.cursor() as cursor:
                cursor.execute("SELECT 1")
                resultado = cursor.fetchone()
                return resultado is not None and resultado[0] == 1
        except Exception:
            return False


def conectar(**kwargs):
    """Cria e retorna uma conexão psycopg2 pura."""
    database_url = kwargs.get("database_url") or os.getenv("DATABASE_URL")
    if database_url:
        return psycopg2.connect(database_url)

    params = {
        "host": kwargs.get("host") or os.getenv("DB_HOST", "localhost"),
        "port": kwargs.get("port") or os.getenv("DB_PORT", "5432"),
        "dbname": kwargs.get("dbname") or os.getenv("DB_NAME"),
        "user": kwargs.get("user") or os.getenv("DB_USER"),
        "password": kwargs.get("password") or os.getenv("DB_PASSWORD"),
    }
    
    # Remove chaves com valores None para não sobrescrever padrões do psycopg2
    params = {k: v for k, v in params.items() if v is not None}
    return psycopg2.connect(**params)


def fechar_conexao(conexao):
    """Fecha a conexão PostgreSQL de forma segura."""
    if conexao and not getattr(conexao, "closed", True):
        conexao.close()


def testar_conexao() -> bool:
    """Função utilitária rápida para testar se as credenciais do .env funcionam."""
    try:
        conexao = conectar()
        with conexao.cursor() as cursor:
            cursor.execute("SELECT 1")
            resultado = cursor.fetchone()
            return resultado is not None and resultado[0] == 1
    except UnicodeDecodeError as e:
        print("Erro do servidor (encoding):", e.object.decode("cp1252", errors="replace"))
        return False
    except Exception as e:
        print("Erro de conexão:", e)
        return False
    finally:
        if 'conexao' in locals():
            fechar_conexao(conexao)
# def garantir_schema(cursor, schema):
#     """Garante que o schema especificado exista no banco de dados."""
#     cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {schema};")

# def criar_tabela(cursor, schema, tabela, colunas):
#     """Cria uma tabela no schema especificado com as colunas fornecidas."""
#     colunas_str = ", ".join([f"{coluna} {tipo}" for coluna, tipo in colunas.items()])
#     cursor.execute(f"CREATE TABLE IF NOT EXISTS {schema}.{tabela} ({colunas_str});")

# def inserir_dados(cursor, schema, tabela, dados):
#     """Insere dados na tabela especificada."""
#     if not dados:
#         return  # Não insere se a lista de dados estiver vazia

#     colunas = ", ".join(dados[0].keys())
#     valores = ", ".join(["%s"] * len(dados[0]))
#     query = f"INSERT INTO {schema}.{tabela} ({colunas}) VALUES ({valores})"
    
#     for linha in dados:
#         cursor.execute(query, tuple(linha.values()))

def main():
    """Função principal para testar a conexão e operações básicas."""
    if testar_conexao():
        print("Conexão bem-sucedida!")
    else:
        print("Falha na conexão.")

if __name__ == "__main__":
    main()
