# olcrtc-binaries

Зеркало CLI-бинарников [openlibrecommunity/olcrtc](https://github.com/openlibrecommunity/olcrtc) для OpenWrt / module-proxy.

Upstream публикует сборки только как GitHub Actions artifact `olcrtc-cli-binaries` (нужен токен, TTL ~90 дней). Этот репозиторий раз в сутки (и по `workflow_dispatch`) забирает свежий артефакт с `master`/`main` и публикует **только latest**:

- `olcrtc-linux-amd64`
- `olcrtc-linux-arm64`

в [Releases](https://github.com/bypassnik/olcrtc-binaries/releases/tag/latest).

Версия в названии релиза и в `SOURCE_SHA` — короткий SHA коммита upstream. Бинарники в git не хранятся.

## Потребители

```text
https://github.com/bypassnik/olcrtc-binaries/releases/latest/download/olcrtc-linux-amd64
https://github.com/bypassnik/olcrtc-binaries/releases/latest/download/olcrtc-linux-arm64
```

module-proxy: `fetch-olcrtc-binary.sh` → `/opt/olcrtc/olcrtc`.

## CI

Workflow `.github/workflows/sync.yml` (cron + `workflow_dispatch`).

Нужен secret **`UPSTREAM_TOKEN`**: fine-grained или classic PAT с правом читать Actions artifacts публичного `openlibrecommunity/olcrtc` (`public_repo` / Contents+Actions read). Без него download API артефактов недоступен.

## Лицензия upstream

olcRTC: WTFPL. Зеркало не изменяет бинарники.
