# Guia -- Como Subir um Novo Serviço com Traefik

## Sumário

- [Guia -- Como Subir um Novo Serviço com Traefik](#guia----como-subir-um-novo-serviço-com-traefik)
  - [Sumário](#sumário)
  - [Pré-Requisitos](#pré-requisitos)
  - [Estrutura de Pastas](#estrutura-de-pastas)
  - [Template Base](#template-base)
  - [Passo a Passo](#passo-a-passo)
    - [1. Criar a pasta do serviço](#1-criar-a-pasta-do-serviço)
    - [2. Escrever o docker-compose.yml](#2-escrever-o-docker-composeyml)
    - [3. Entender cada label](#3-entender-cada-label)
      - [Traefik Labels vs Docker Network -- São coisas diferentes](#traefik-labels-vs-docker-network----são-coisas-diferentes)
      - [Referência das labels](#referência-das-labels)
    - [4. Subir o serviço](#4-subir-o-serviço)
    - [5. Verificar no Dashboard](#5-verificar-no-dashboard)
  - [Diagrama de Decisão de Labels](#diagrama-de-decisão-de-labels)
  - [Cenários Comuns](#cenários-comuns)
    - [Cenário 1 -- Serviço web simples](#cenário-1----serviço-web-simples)
    - [Cenário 2 -- Serviço com BasicAuth](#cenário-2----serviço-com-basicauth)
    - [Cenário 3 -- Serviço em múltiplas redes](#cenário-3----serviço-em-múltiplas-redes)
    - [Cenário 4 -- Serviço interno (sem Traefik)](#cenário-4----serviço-interno-sem-traefik)
    - [Cenário 5 -- API com acesso a banco de dados](#cenário-5----api-com-acesso-a-banco-de-dados)
  - [Checklist de Verificação](#checklist-de-verificação)
    - [Docker Compose](#docker-compose)
    - [Labels do Traefik](#labels-do-traefik)
    - [DNS](#dns)
    - [Pós-Deploy](#pós-deploy)
  - [Troubleshooting](#troubleshooting)
    - [404 Not Found](#404-not-found)
    - [502 Bad Gateway](#502-bad-gateway)
    - [503 Service Unavailable](#503-service-unavailable)
    - [Certificado TLS inválido / ERR\_CERT\_AUTHORITY\_INVALID](#certificado-tls-inválido--err_cert_authority_invalid)
    - [Container não aparece no Dashboard do Traefik](#container-não-aparece-no-dashboard-do-traefik)
    - [Timeout / Conexão recusada](#timeout--conexão-recusada)
    - [Erro de BasicAuth (401 repetido)](#erro-de-basicauth-401-repetido)

---

## Pré-Requisitos

Antes de subir qualquer novo serviço, confirme:

1. **Traefik está rodando**: `docker ps | grep traefik`
2. **Rede `production` existe**: `docker network ls | grep production`
3. **DNS configurado**: O subdomínio deve apontar para o IP do servidor no Cloudflare (ou usar o wildcard `*.facihub.com.br` que já está configurado)
4. **Certificado wildcard ativo**: Como usamos `*.facihub.com.br`, qualquer subdomínio já tem TLS automaticamente

Se a rede `production` não existir:

```bash
docker network create production
```

---

## Estrutura de Pastas

O repositório segue este padrão:

```
Infra-com-Traefik/
├── Infrastructure/
│   ├── traefik/          # Reverse proxy (já configurado)
│   ├── nginx/            # Landing page
│   ├── portainer/        # Gerenciamento Docker
│   ├── grafana/          # Dashboards
│   ├── prometheus/       # Métricas
│   └── <novo-servico>/   # <-- Crie aqui serviços de infra
├── Databases/
│   ├── mysql/
│   ├── postgres/
│   └── redis/
└── docs/
```

Para **novos serviços de infraestrutura**, crie a pasta dentro de `Infrastructure/`.
Para **aplicações de negócio** (APIs, frontends), considere criar uma pasta `Applications/` na raiz.

---

## Template Base

> **Atenção**: Este template é exclusivamente para serviços que precisam de **acesso externo** via subdomínio (ex: APIs, painéis web, frontends). Serviços internos como filas de mensagens (RabbitMQ, SQS), servidores de email, workers em background ou qualquer serviço que não deve ser acessado pela internet **não devem ter labels do Traefik**. Para esses casos, veja o [Cenário 4 -- Serviço interno](#cenário-4----serviço-interno-sem-traefik).

Este é o `docker-compose.yml` mínimo para expor um serviço via Traefik:

```yaml
networks:
  production:
    external: true
    name: production

services:
  meu-servico:
    image: imagem:tag
    container_name: meu-servico
    restart: unless-stopped
    networks:
      - production
    labels:
      - traefik.enable=true
      - traefik.http.routers.meu-servico.rule=Host(`meu-servico.facihub.com.br`)
      - traefik.http.routers.meu-servico.entrypoints=websecure
      - traefik.http.routers.meu-servico.tls=true
      - traefik.http.services.meu-servico.loadbalancer.server.port=PORTA_INTERNA
```

Substitua:
- `meu-servico` pelo nome do seu serviço (usado como identificador em routers e services)
- `imagem:tag` pela imagem Docker
- `meu-servico.facihub.com.br` pelo subdomínio desejado
- `PORTA_INTERNA` pela porta que o container escuta internamente

---

## Passo a Passo

### 1. Criar a pasta do serviço

```bash
mkdir -p Infrastructure/meu-servico
cd Infrastructure/meu-servico
```

### 2. Escrever o docker-compose.yml

Crie o arquivo usando o [Template Base](#template-base) e ajuste para o seu caso. Exemplo para uma aplicação Node.js na porta 3000:

```yaml
networks:
  production:
    external: true
    name: production

services:
  minha-app:
    image: minha-app:latest
    container_name: minha-app
    restart: unless-stopped
    environment:
      - NODE_ENV=production
    networks:
      - production
    labels:
      - traefik.enable=true
      - traefik.http.routers.minha-app.rule=Host(`app.facihub.com.br`)
      - traefik.http.routers.minha-app.entrypoints=websecure
      - traefik.http.routers.minha-app.tls=true
      - traefik.http.services.minha-app.loadbalancer.server.port=3000
```

### 3. Entender cada label

#### Traefik Labels vs Docker Network -- São coisas diferentes

Antes de ver as labels, entenda a distinção fundamental:

|                        | Rede Docker                                                                | Labels do Traefik                              |
|------------------------|----------------------------------------------------------------------------|------------------------------------------------|
| **Função** ------------| Comunicação **interna** entre containers ----------------------------------| Exposição **externa** (internet -> container) -|
| **Quem controla** -----| Docker Engine -------------------------------------------------------------| Traefik ---------------------------------------|
| **Como funciona** -----| Containers na mesma rede se acessam por nome (ex: `http://minha-api:3000`) | Traefik roteia requisições externas por subdomínio para o container |
| **Precisa de labels?** | Não. Basta estar na mesma rede. -------------------------------------------| Sim. Sem labels, o Traefik ignora o container. |

**Exemplo prático**: Um worker na rede `production` **sem nenhuma label do Traefik** consegue acessar `http://nginx:80`, `http://grafana:3000` e qualquer outro container nessa rede normalmente. As labels do Traefik **não interferem** na comunicação interna do Docker.

**Quando usar labels do Traefik**: Somente quando o serviço precisa ser acessado pela **internet** via subdomínio (ex: `api.facihub.com.br`). Serviços internos (workers, filas, email, etc.) não devem ter labels do Traefik.

#### Referência das labels

Cada label tem uma função específica. Aqui está o que cada uma faz:

```yaml
# OBRIGATÓRIO: Diz ao Traefik para descobrir este container
- traefik.enable=true

# OBRIGATÓRIO: Regra de roteamento baseada no header Host
# O Traefik compara o domínio da requisição com esta regra
- traefik.http.routers.NOME.rule=Host(`subdominio.facihub.com.br`)

# OBRIGATÓRIO: Em qual entrypoint escutar (websecure = porta 443)
- traefik.http.routers.NOME.entrypoints=websecure

# OBRIGATÓRIO: Ativa TLS no router
- traefik.http.routers.NOME.tls=true

# OBRIGATÓRIO*: Porta interna do container (*opcional se o container expõe apenas 1 porta)
- traefik.http.services.NOME.loadbalancer.server.port=PORTA

# OPCIONAL: Especifica o cert resolver (se quiser forçar, normalmente herdado do entrypoint)
- traefik.http.routers.NOME.tls.certresolver=letsencrypt

# CONDICIONAL: Obrigatório se o container está em múltiplas redes
- traefik.docker.network=production

# OPCIONAL: Associa middlewares ao router (ex: autenticação)
- traefik.http.routers.NOME.middlewares=nome-do-middleware
```

> **NOME** é um identificador que você escolhe. Por convenção, use o mesmo nome do serviço. Deve ser consistente entre routers e services.

### 4. Subir o serviço

```bash
cd Infrastructure/meu-servico
docker compose up -d
```

O Traefik detecta o novo container automaticamente via Docker Socket. Não é preciso reiniciar nada.

Para verificar se o container subiu corretamente:

```bash
docker compose ps
docker compose logs -f
```

### 5. Verificar no Dashboard

Acesse `https://traefik.facihub.com.br` e confirme que:

1. Um novo **Router** apareceu com a regra `Host(...)` correta
2. Um novo **Service** apareceu apontando para a porta correta
3. O status está **verde** (sem erros)

Teste o acesso direto no navegador:

```bash
curl -I https://meu-servico.facihub.com.br
```

Resposta esperada: `HTTP/2 200` (ou o código que seu serviço retornar).

---

## Diagrama de Decisão de Labels

Use este fluxograma para decidir quais labels adicionar:

```mermaid
flowchart TD
    Start["Novo serviço Docker"] --> Q1{"Precisa ser acessado\npela internet?"}
    Q1 -->|Não| NoTraefik["Não adicione labels do Traefik.\nApenas configure a rede necessária."]
    Q1 -->|Sim| Base["Adicione as 5 labels obrigatórias:\nenable, router rule, entrypoints,\ntls, service port"]

    Base --> Q2{"Container está em\nmúltiplas redes?"}
    Q2 -->|Sim| DockerNet["Adicione:\ntraefik.docker.network=production"]
    Q2 -->|Não| Q3

    DockerNet --> Q3{"Precisa de\nautenticação?"}
    Q3 -->|Sim| Auth["Adicione middleware BasicAuth:\nmiddlewares.NOME-auth.basicauth.users\nrouters.NOME.middlewares=NOME-auth"]
    Q3 -->|Não| Done["Pronto para subir"]
    Auth --> Done
```

---

## Cenários Comuns

### Cenário 1 -- Serviço web simples

O caso mais básico. Um container com uma porta, uma rede, sem middlewares.

**Exemplo real**: Nginx servindo a landing page em `facihub.com.br`

```yaml
# Infrastructure/nginx/docker-compose.yml
networks:
  production:
    external: true
    name: production

services:
  nginx:
    image: nginx:alpine
    container_name: nginx
    restart: unless-stopped
    volumes:
      - ./site:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - production
    labels:
      - traefik.enable=true
      - traefik.http.routers.nginx.rule=Host(`facihub.com.br`)
      - traefik.http.routers.nginx.entrypoints=websecure
      - traefik.http.routers.nginx.tls=true
      - traefik.http.routers.nginx.tls.certresolver=letsencrypt
      - traefik.http.services.nginx.loadbalancer.server.port=80
```

Pontos-chave:
- Rede única (`production`) -- não precisa de `traefik.docker.network`
- Sem middlewares -- acesso público direto
- `certresolver=letsencrypt` explícito (opcional, já que o entrypoint herda)

---

### Cenário 2 -- Serviço com BasicAuth

Protege o acesso com usuário e senha no nível do Traefik, antes de chegar ao container.

**Exemplo real**: Prometheus em `prometheus.facihub.com.br`

```yaml
# Infrastructure/prometheus/docker-compose.yml (parcial)
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    labels:
      - traefik.enable=true
      - traefik.http.routers.prometheus.rule=Host(`prometheus.facihub.com.br`)
      - traefik.http.routers.prometheus.entrypoints=websecure
      - traefik.http.routers.prometheus.tls=true
      - traefik.http.services.prometheus.loadbalancer.server.port=9090
      # Middleware de autenticação
      - traefik.http.middlewares.prometheus-auth.basicauth.users=admin:$$2a$$10$$hash...
      - traefik.http.routers.prometheus.middlewares=prometheus-auth
      # Rede explícita (está em production + monitoring)
      - traefik.docker.network=production
    networks:
      - monitoring
      - production
```

Para gerar o hash da senha:

```bash
# Instale htpasswd (apache2-utils no Ubuntu)
sudo apt install apache2-utils

# Gere o hash
htpasswd -nbB admin "sua-senha-aqui"
# Saída: admin:$2y$05$hash...

# No docker-compose.yml, duplique cada $ para $$
# admin:$2y$05$abc -> admin:$$2y$$05$$abc
```

Pontos-chave:
- O middleware é **definido** em uma label e **associado** ao router em outra
- O nome do middleware (`prometheus-auth`) é livre, mas deve ser consistente
- `$$` no compose é escape de `$` (o YAML interpreta `$` como variável)

---

### Cenário 3 -- Serviço em múltiplas redes

Quando o container precisa estar em mais de uma rede Docker.

**Exemplo real**: Grafana em `production` (Traefik) + `monitoring` (Prometheus/Exporters)

```yaml
# Infrastructure/grafana/docker-compose.yml
networks:
  monitoring:
    external: true
    name: monitoring
  production:
    external: true
    name: production

services:
  grafana:
    image: grafana/grafana:main-ubuntu
    container_name: grafana
    restart: unless-stopped
    environment:
      - GF_SERVER_ROOT_URL=https://grafana.facihub.com.br
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - monitoring      # Acessa Prometheus e exporters
      - production       # Acessível via Traefik
    labels:
      - traefik.enable=true
      - traefik.http.routers.grafana.rule=Host(`grafana.facihub.com.br`)
      - traefik.http.routers.grafana.entrypoints=websecure
      - traefik.http.routers.grafana.tls=true
      - traefik.http.services.grafana.loadbalancer.server.port=3000
      - traefik.docker.network=production  # OBRIGATÓRIO aqui

volumes:
  grafana_data:
    driver: local
    name: grafana_data
```

Pontos-chave:
- **`traefik.docker.network=production`** é obrigatório porque o container está em duas redes. Sem isso, o Traefik pode tentar usar a rede `monitoring` e falhar
- Ambas as redes são declaradas como `external: true` (já existem no host)
- O Grafana acessa datasources do Prometheus via `prometheus:9090` na rede `monitoring`

---

### Cenário 4 -- Serviço interno (sem Traefik)

Serviços que não precisam de acesso externo. Bancos de dados são o exemplo clássico.

**Exemplo real**: MySQL

```yaml
# Databases/mysql/docker-compose.yml (parcial)
networks:
  databases:
    external: true
    name: databases

services:
  mysql:
    image: mysql:8.0
    container_name: mysql
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - databases        # Apenas na rede interna
    # SEM labels do Traefik -> invisível para o mundo externo
```

Pontos-chave:
- **Sem labels do Traefik** -- o container não é descoberto
- Acessível apenas por outros containers na rede `databases` via `mysql:3306`
- Pode expor a porta no host (`ports: "3306:3306"`) para acesso de ferramentas locais, mas isso é separado do Traefik

---

### Cenário 5 -- API com acesso a banco de dados

O cenário mais comum para aplicações: precisa receber tráfego externo (Traefik) e acessar bancos internos.

```yaml
networks:
  production:
    external: true
    name: production
  databases:
    external: true
    name: databases

services:
  minha-api:
    image: minha-api:latest
    container_name: minha-api
    restart: unless-stopped
    environment:
      - DATABASE_URL=mysql://user:pass@mysql:3306/meudb
      - REDIS_URL=redis://redis:6379
    networks:
      - production       # Acessível via Traefik
      - databases        # Acessa MySQL, PostgreSQL, Redis
    labels:
      - traefik.enable=true
      - traefik.http.routers.minha-api.rule=Host(`api.facihub.com.br`)
      - traefik.http.routers.minha-api.entrypoints=websecure
      - traefik.http.routers.minha-api.tls=true
      - traefik.http.services.minha-api.loadbalancer.server.port=3000
      - traefik.docker.network=production  # OBRIGATÓRIO: múltiplas redes
```

Pontos-chave:
- Duas redes: `production` para Traefik + `databases` para acessar bancos
- Connection strings usam **nomes de containers**: `mysql:3306`, `redis:6379`, `postgres:5432`
- `traefik.docker.network=production` é obrigatório (múltiplas redes)
- Os bancos de dados continuam inacessíveis pela internet

---

## Checklist de Verificação

Antes de fazer deploy, confirme cada item:

### Docker Compose

- [ ] Rede `production` declarada como `external: true`
- [ ] Container conectado à rede `production`
- [ ] `container_name` definido (facilita identificação nos logs e DNS)
- [ ] `restart: unless-stopped` configurado

### Labels do Traefik

- [ ] `traefik.enable=true` presente
- [ ] Router rule com `Host(...)` apontando para o subdomínio correto
- [ ] Router entrypoints = `websecure`
- [ ] Router tls = `true`
- [ ] Service loadbalancer port com a porta correta do container
- [ ] Se múltiplas redes: `traefik.docker.network=production`
- [ ] Se precisa autenticação: middleware de BasicAuth configurado e associado

### DNS

- [ ] Subdomínio aponta para o IP do servidor (ou wildcard `*.facihub.com.br` já cobre)

### Pós-Deploy

- [ ] Container rodando: `docker ps | grep meu-servico`
- [ ] Sem erros nos logs: `docker compose logs meu-servico`
- [ ] Router visível no dashboard do Traefik
- [ ] Acesso HTTPS funciona: `curl -I https://meu-servico.facihub.com.br`

---

## Troubleshooting

### 404 Not Found

**Causa**: O Traefik não encontrou nenhum router que faça match com o domínio.

Verifique:
1. O container está rodando? `docker ps | grep meu-servico`
2. A label `traefik.enable=true` existe?
3. O `Host(...)` na label está correto e com crases `` ` `` (não aspas)?
4. O container está na rede `production`?

### 502 Bad Gateway

**Causa**: O Traefik encontrou o router, mas não consegue se comunicar com o container.

Verifique:
1. A **porta** na label `loadbalancer.server.port` está correta? É a porta **interna** do container, não a porta do host
2. O container está respondendo na porta indicada? `docker exec meu-servico curl localhost:PORTA`
3. Se o container está em múltiplas redes, `traefik.docker.network=production` está definido?

### 503 Service Unavailable

**Causa**: O serviço está registrado mas o container não está saudável.

Verifique:
1. O container está em estado healthy? `docker inspect meu-servico | grep Health`
2. O container reiniciou recentemente? `docker ps` (verifique a coluna STATUS)
3. Logs do container: `docker compose logs -f meu-servico`

### Certificado TLS inválido / ERR_CERT_AUTHORITY_INVALID

**Causa**: O certificado não cobre o subdomínio.

Verifique:
1. O subdomínio é `*.facihub.com.br`? Subdomínios de segundo nível (ex: `sub.sub.facihub.com.br`) **não** são cobertos pelo wildcard
2. O `acme.json` existe e tem permissão 600? `ls -la Infrastructure/traefik/certs/acme.json`
3. Logs do Traefik: `docker logs traefik 2>&1 | grep -i acme`

### Container não aparece no Dashboard do Traefik

**Causa**: O Traefik não está descobrindo o container.

Verifique:
1. Label `traefik.enable=true` existe?
2. O container e o Traefik compartilham pelo menos uma rede? (`production`)
3. O Traefik tem acesso ao Docker socket? `docker logs traefik 2>&1 | grep -i provider`

### Timeout / Conexão recusada

**Causa**: Problema de rede entre o Traefik e o container.

Verifique:
1. O container está na rede certa? `docker inspect meu-servico --format='{{json .NetworkSettings.Networks}}' | python3 -m json.tool`
2. Teste conectividade: `docker exec traefik wget -qO- http://meu-servico:PORTA` (substitua PORTA)
3. O firewall do host bloqueia algo? `ufw status` ou `iptables -L`

### Erro de BasicAuth (401 repetido)

**Causa**: Hash de senha incorreto ou formatação errada no YAML.

Verifique:
1. O hash foi gerado com `htpasswd -nbB`?
2. Cada `$` no hash foi duplicado para `$$` no compose?
3. O middleware está associado ao router correto na label `middlewares=`?
