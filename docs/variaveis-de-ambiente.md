# Variáveis de Ambiente

Referência de todas as variáveis de ambiente utilizadas no projeto.

---

## Global

| Variável | Descrição | Usado em |
|----------|-----------|----------|
| `DOMAIN` | Domínio base da aplicação | Todos os docker-compose (labels Traefik) |

---

## Backend — `Backend/api-catalog/.env`

| Variável | Descrição | Exemplo |
|----------|-----------|---------|
| `DOCKERHUB_REPO` | Repositório da imagem no DockerHub | `facimed/api-catalogo` |
| `IMAGE_TAG` | Tag da imagem Docker | `latest` |
| `MYSQL_DATABASE` | Nome do banco de dados | `facihub` |
| `MYSQL_USER` | Usuário do banco de dados | `facihub` |
| `MYSQL_PASSWORD` | Senha do usuário do banco | - |
| `RABBITMQ_USER` | Usuário do RabbitMQ | `admin` |
| `RABBITMQ_PASSWORD` | Senha do RabbitMQ | - |
| `DB_SCHEMA` | Schema utilizado pela aplicação | `SaaS` |

---

## Databases — `Databases/mysql/.env`

### MySQL Server

| Variável | Descrição | Exemplo |
|----------|-----------|---------|
| `MYSQL_ROOT_PASSWORD` | Senha do root do MySQL | - |
| `MYSQL_DATABASE` | Database criado na inicialização | `facihub` |
| `MYSQL_USER` | Usuário criado na inicialização | `facihub` |
| `MYSQL_PASSWORD` | Senha do usuário | - |

### MySQL Exporter (Prometheus)

| Variável | Descrição | Exemplo |
|----------|-----------|---------|
| `MYSQL_EXPORTER_USER` | Usuário do exporter de métricas | `exporter` |
| `MYSQL_EXPORTER_PASSWORD` | Senha do exporter | - |

### Setup de Tabelas

| Variável | Descrição | Exemplo |
|----------|-----------|---------|
| `SQL_SCRIPTS_PATH` | Caminho local dos scripts SQL | `/opt/sql-scripts` |

---

## GitHub Actions — Secrets do repositório

| Secret | Descrição | Usado em |
|--------|-----------|----------|
| `HOST` | IP ou hostname do servidor | Todas as pipelines |
| `USERNAME` | Usuário SSH do servidor | Todas as pipelines |
| `SSH_PRIVATE_KEY` | Chave privada SSH | Todas as pipelines |

---

## Onde cada `.env` é utilizado

```
myhub-server-infra/
├── Backend/
│   └── api-catalog/
│       ├── .env              ← DOCKERHUB_REPO, IMAGE_TAG, DB_*, RABBITMQ_*, DOMAIN
│       └── docker-compose.yml
└── Databases/
    └── mysql/
        ├── .env              ← MYSQL_*, MYSQL_EXPORTER_*, SQL_SCRIPTS_PATH, DOMAIN
        ├── docker-compose.yml
        └── docker-compose.setup-tables.yml
```

> Os serviços de `Infrastructure/` não possuem `.env`. Para que a variável `DOMAIN` seja resolvida, crie um `.env` na pasta de cada serviço com `DOMAIN=facihub.com.br`.
