#!/bin/bash
set -e

echo "=============================================="
echo "  DATABASE SETUP - Configuração Inicial"
echo "=============================================="
echo ""
echo "  Host: ${DB_HOST}:${DB_PORT}"
echo "  Database: ${DB_NAME}"
echo "  Usuário: ${DB_USER}"
echo ""

echo "Aguardando banco de dados estar pronto..."
until mysql -h"${DB_HOST}" -P"${DB_PORT}" -uroot -p"${DB_ROOT_PASSWORD}" -e "SELECT 1" &> /dev/null; do
    echo "  Aguardando MySQL..."
    sleep 2
done
echo "Banco de dados está pronto!"
echo ""

mysql -h"${DB_HOST}" -P"${DB_PORT}" -uroot -p"${DB_ROOT_PASSWORD}" <<-EOSQL
    CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
      CHARACTER SET utf8mb4
      COLLATE utf8mb4_0900_ai_ci;

    CREATE USER IF NOT EXISTS '${DB_USER}'@'%'
      IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';

    ALTER USER '${DB_USER}'@'%'
      IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';

    GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';

    FLUSH PRIVILEGES;

    SELECT
        'Database criada com sucesso!' as Status,
        '${DB_NAME}' as Database_Name,
        '${DB_USER}' as App_User;
EOSQL

echo ""
echo "=============================================="
echo "  Banco de dados configurado com sucesso!"
echo "=============================================="
echo "  Database: ${DB_NAME}"
echo "  Usuário:  ${DB_USER}"
echo "  Host:     ${DB_HOST}:${DB_PORT}"
echo "=============================================="
