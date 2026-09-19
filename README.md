# Pi Agent Dockerfile Project

> This project provides a Dockerfile to build and deploy a Pi Agent container with one command. It runs Pi Agent in an isolated container environment and supports flexible configuration through files in the `metadata/` folder.

## Metadata Files

| File | Description |
|------|-------------|
| `auth.json` | Pi Agent auth file, mapped to `.pi/agent/auth.json` |
| `settings.json` | Pi Agent settings file, mapped to `.pi/agent/settings.json` |
| `gh_config.json` | GitHub CLI (`gh`) configuration |
| `tea_config.json` | Tea configuration |
| `MEMORY.md` | Memory file for `pi-memory` |
| `PROMPT.md` | Appended to Pi Agent system prompt |
| `retry.json` | Retry rules for `pi-goal-list-loop-audit` |
| `web-search.json` | Settings for `pi-web-access` |
| `external.sh.demo` | Script executed at the final build step |

Copy the `.demo` files, rename them, and edit as needed before building.


## How to Use?

1. Create the config files you need in the `metadata/` folder.
2. Build the image with Docker:
```bash
docker build -t pi-agent .
```
3. Run the container in the background:
```bash
docker run -d --name pi-agent pi-agent
```
4. Enter the container manually:
```bash
docker exec -it pi-agent bash
```