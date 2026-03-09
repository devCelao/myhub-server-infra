# Infra-com-Traefik

Infraestrutura completa do servidor VPS (Hostinger) para o domínio **facihub.com.br**, usando Traefik como reverse proxy central com TLS automático via Let's Encrypt.

## Estrutura

```
├── Infrastructure/
│   ├── traefik/        # Reverse proxy + TLS (wildcard *.facihub.com.br)
│   ├── nginx/          # Landing page (facihub.com.br)
│   ├── portainer/      # Gerenciamento Docker (portainer.facihub.com.br)
│   ├── grafana/        # Dashboards de monitoramento (grafana.facihub.com.br)
│   └── prometheus/     # Coleta de métricas (prometheus.facihub.com.br)
├── Databases/
│   ├── mysql/          # MySQL 8.0 + Exporter
│   ├── postgres/       # PostgreSQL 16 + PgAdmin + Exporter
│   └── redis/          # Redis + Exporter
├── docs/
│   ├── traefik-funcionamento.md   # Como o Traefik funciona com Docker
│   └── guia-novo-servico.md       # Como subir um novo serviço
└── .github/workflows/
    └── deploy.yml      # CI/CD via GitHub Actions
```

## Redes Docker

| Rede         | Função                                                    |
|--------------|-----------------------------------------------------------|
| `production` | Conecta Traefik aos serviços expostos externamente -------|
| `monitoring` | Comunicação entre Prometheus, Grafana e exporters --------|
| `databases` -| Isolamento dos bancos de dados (MySQL, PostgreSQL, Redis) |

## Serviços expostos

| Serviço           | URL                         |
|-------------------|-----------------------------|
| Landing Page -----| `facihub.com.br` -----------|
| Traefik Dashboard | `traefik.facihub.com.br` ---|
| Portainer --------| `portainer.facihub.com.br` -|
| Grafana ----------| `grafana.facihub.com.br` ---|
| Prometheus -------| `prometheus.facihub.com.br` |
| PgAdmin ----------| `pgadmin.facihub.com.br` ---|

## Documentação

- **[Como o Traefik funciona](docs/traefik-funcionamento.md)** -- Arquitetura, conceitos, redes, TLS, fluxo de requisições
- **[Como subir um novo serviço](docs/guia-novo-servico.md)** -- Template, passo a passo, cenários e troubleshooting