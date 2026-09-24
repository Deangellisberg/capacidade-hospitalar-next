import os

import psycopg2
from dotenv import load_dotenv


load_dotenv()


def conectar():
	"""Cria uma conexão PostgreSQL usando as variáveis definidas no .env."""
	database_url = os.getenv("DATABASE_URL")
	if database_url:
		return psycopg2.connect(database_url)

	return psycopg2.connect(
		host=os.getenv("DB_HOST", "localhost"),
		port=os.getenv("DB_PORT", "5432"),
		dbname=os.getenv("DB_NAME"),
		user=os.getenv("DB_USER"),
		password=os.getenv("DB_PASSWORD"),
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

def garantir_schema(cursor, schema):
    """Garante que o schema especificado exista no banco de dados."""
    cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {schema};")

def criar_tabela(cursor, schema, tabela, colunas):
    """Cria uma tabela no schema especificado com as colunas fornecidas."""
    colunas_str = ", ".join([f"{coluna} {tipo}" for coluna, tipo in colunas.items()])
    cursor.execute(f"CREATE TABLE IF NOT EXISTS {schema}.{tabela} ({colunas_str});")

def inserir_dados(cursor, schema, tabela, dados):
    """Insere dados na tabela especificada."""
    if not dados:
        return  # Não insere se a lista de dados estiver vazia

    colunas = ", ".join(dados[0].keys())
    valores = ", ".join(["%s"] * len(dados[0]))
    query = f"INSERT INTO {schema}.{tabela} ({colunas}) VALUES ({valores})"
    
    for linha in dados:
        cursor.execute(query, tuple(linha.values()))

def main():
    """Função principal para testar a conexão e operações básicas."""
    if testar_conexao():
        print("Conexão bem-sucedida!")
    else:
        print("Falha na conexão.")

if __name__ == "__main__":
    main()
