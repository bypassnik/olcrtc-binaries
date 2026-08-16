# olcrtc-binaries

Public mirror of CLI binaries from [openlibrecommunity/olcrtc](https://github.com/openlibrecommunity/olcrtc).

Upstream publishes builds only as the GitHub Actions artifact `olcrtc-cli-binaries` (authenticated download, ~90 day TTL). This repository pulls the latest artifact from `master`/`main` daily (and on `workflow_dispatch`) and keeps **only one** Release (`latest`):

- `olcrtc-linux-amd64`
- `olcrtc-linux-arm64`

See [Releases](https://github.com/bypassnik/olcrtc-binaries/releases/tag/latest).

The Release title and `SOURCE_SHA` asset are the short upstream commit SHA. Binaries are not stored in git history.

## Download

```text
https://github.com/bypassnik/olcrtc-binaries/releases/latest/download/olcrtc-linux-amd64
https://github.com/bypassnik/olcrtc-binaries/releases/latest/download/olcrtc-linux-arm64
```

## CI

Workflow `.github/workflows/sync.yml` (cron + `workflow_dispatch`).

Requires secret **`UPSTREAM_TOKEN`**: a PAT that can read Actions artifacts from public `openlibrecommunity/olcrtc` (`public_repo` / Contents+Actions read). The default `GITHUB_TOKEN` cannot download cross-repo Actions artifacts.

## Upstream license

olcRTC: WTFPL. This mirror does not modify the binaries.
