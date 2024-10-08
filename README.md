# docker-maxkb

MaxKB 容器化部署

## 使用说明

```sh
git clone https://github.com/wojiushixiaobai/docker-maxkb --depth 1
cd docker-maxkb
```

```sh
cp env.example .env
```

```sh
vim .env
```

```vim
# Description: Environment variables for Nextcloud
COMPOSE_PROJECT_NAME=1p

# 数据库配置，POSTGRES_PASSWORD 需要填一下
DB_HOST=postgresql
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=********
DB_NAME=maxkb

# Web 访问端口
HTTP_PORT=8080
```

```sh
docker compose up -d
```

## 登录凭据

- 账号：`admin`
- 密码：`MaxKB@123..`

