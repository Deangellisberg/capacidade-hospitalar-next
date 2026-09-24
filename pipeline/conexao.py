import os
from abc import ABC, abstractmethod

import psycopg2
from dotenv import load_dotenv


load_dotenv()


class conexao(ABC):
    """Contrato de conexão e operações básicas do banco de dados."""

    def __init__(self, **kwargs):
        self.conn = None
        self.kwargs = kwargs or self._default_kwargs()

    @staticmethod
    def _default_kwargs():
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
    def executar(self, query, params=None):
        """Executa uma instrução SQL e retorna a quantidade de linhas afetadas."""
        raise NotImplementedError

    @abstractmethod
    def consultar(self, query, params=None):
        """Executa uma consulta SQL e retorna todas as linhas do resultado."""
        raise NotImplementedError

    @abstractmethod
    def testar(self):
        """Valida se a conexão com o banco está ativa."""
        raise NotImplementedError

    def __enter__(self):
        self.conectar()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.fechar()
        return False


class Conexao(conexao):
    """Implementação concreta de conexão PostgreSQL com helpers úteis."""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def conectar(self):
        if self.conn is not None and getattr(self.conn, "closed", 0) == 0:
            return self.conn

        self.conn = conectar(**self.kwargs)
        return self.conn

    def fechar(self):
        if self.conn is not None:
            fechar_conexao(self.conn)
            self.conn = None

    def executar(self, query, params=None):
        if self.conn is None:
            self.conectar()

        with self.conn.cursor() as cursor:
            if params is None:
                cursor.execute(query)
            else:
                cursor.execute(query, params)
            return cursor.rowcount

    def consultar(self, query, params=None):
        if self.conn is None:
            self.conectar()

        with self.conn.cursor() as cursor:
            if params is None:
                cursor.execute(query)
            else:
                cursor.execute(query, params)
            return cursor.fetchall()

    def testar(self):
        try:
            if self.conn is None:
                self.conectar()

            with self.conn.cursor() as cursor:
                cursor.execute("SELECT 1")
                resultado = cursor.fetchone()
                return resultado is not None and resultado[0] == 1
        except Exception:
            return False
        finally:
            if self.conn is not None:
                self.fechar()


def conectar(**kwargs):
	"""Cria uma conexão PostgreSQL usando as variáveis definidas no .env."""
	database_url = kwargs.pop("database_url", None) or os.getenv("DATABASE_URL")
	if database_url:
		return psycopg2.connect(database_url)

	return psycopg2.connect(
		host=kwargs.get("host", os.getenv("DB_HOST", "localhost")),
		port=kwargs.get("port", os.getenv("DB_PORT", "5432")),
		dbname=kwargs.get("dbname", os.getenv("DB_NAME")),
		user=kwargs.get("user", os.getenv("DB_USER")),
		password=kwargs.get("password", os.getenv("DB_PASSWORD")),
	)

def fechar_conexao(conexao):
    """Fecha a conexão PostgreSQL."""
    if conexao:
        conexao.close()

def testar_conexao():
    """Testa a conexão e fecha os recursos utilizados."""
    try:
        conexao = conectar()
    except UnicodeDecodeError as e:
        print("Erro do servidor:", e.object.decode("cp1252", errors="replace"))
        return False

    try:
        with conexao.cursor() as cursor:
            cursor.execute("SELECT 1")
            resultado = cursor.fetchone()
            return resultado is not None and resultado[0] == 1
    finally:
        conexao.close()

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
