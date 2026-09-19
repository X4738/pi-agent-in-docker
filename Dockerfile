FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.local/bin:/usr/local/bin:${PATH}"

WORKDIR /root

RUN apt update \
    && apt install -y --no-install-recommends \
        bash ca-certificates curl wget gnupg git openssh-client jq ripgrep fd-find \
        python3 procps findutils coreutils grep sed gawk tar gzip xz-utils unzip zip \
        build-essential ffmpeg yt-dlp nodejs npm tmux \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN mkdir -p -m 755 /etc/apt/keyrings /etc/apt/sources.list.d \
    && out="$(mktemp)" \
    && wget -nv -O "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat "$out" > /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt update \
    && apt install -y --no-install-recommends gh \
    && rm -f "$out" \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN curl -fsSL https://pi.dev/install.sh | sh

RUN npm install -g @tobilu/qmd@latest \
    && pi install npm:@monotykamary/pi-retry --no-approve \
    && pi install npm:pi-web-access --no-approve \
    && pi install npm:pi-vision --no-approve \
    && pi install npm:pi-subagents --no-approve \
    && pi install npm:pi-memory --no-approve \
    && pi install npm:pi-goal-list-loop-audit --no-approve \
    && npm cache clean --force

RUN arch="$(dpkg --print-architecture)" \
    && case "$arch" in \
         amd64) tea_arch="amd64" ;; \
         arm64) tea_arch="arm64" ;; \
         armhf) tea_arch="arm-6" ;; \
         *) echo "Unsupported tea architecture: $arch" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://dl.gitea.com/tea/main/tea-main-linux-${tea_arch}" -o /usr/local/bin/tea \
    && chmod 0755 /usr/local/bin/tea

RUN mkdir -p /root/.pi/agent/memory /root/.config/gh /root/.config/tea /opt/agent-metadata

COPY metadata/ /opt/agent-metadata/

RUN set -eu; \
    copy_if_present() { \
      source="$1"; destination="$2"; \
      if [ -f "$source" ]; then \
        mkdir -p "$(dirname "$destination")"; \
        cat "$source" > "$destination"; \
      fi; \
    }; \
    copy_if_present /opt/agent-metadata/models.json /root/.pi/agent/models.json; \
    copy_if_present /opt/agent-metadata/auth.json /root/.pi/agent/auth.json; \
    copy_if_present /opt/agent-metadata/web-search.json /root/.pi/agent/web-search.json; \
    copy_if_present /opt/agent-metadata/PROMPT.md /root/.pi/agent/APPEND_SYSTEM.md; \
    if [ -f /opt/agent-metadata/MEMORY.md ]; then \
      cat /opt/agent-metadata/MEMORY.md > /root/.pi/agent/memory/MEMORY.md; \
    fi; \
    if [ -f /opt/agent-metadata/settings.json ]; then \
      jq -e . /opt/agent-metadata/settings.json >/dev/null; \
      cat /opt/agent-metadata/settings.json > /root/.pi/agent/settings.json; \
    else \
      printf '%s\n' '{}' > /root/.pi/agent/settings.json; \
    fi; \
    retry_settings="$(mktemp)"; \
    jq -e \
      --argjson retry '{"enabled":true,"maxRetries":1000000,"baseDelayMs":10000,"maxAgentDelayMs":10000,"provider":{"timeoutMs":3600000,"maxRetries":0,"maxRetryDelayMs":10000}}' \
      --argjson pi_retry '{"baseDelayMs":10000,"maxDelayMs":10000,"multiplier":1,"maxRetriesAtMaxDelay":1000000}' \
      '. * {"retry": $retry, "piRetry": $pi_retry}' \
      /root/.pi/agent/settings.json > "$retry_settings"; \
    cat "$retry_settings" > /root/.pi/agent/settings.json; \
    rm -f "$retry_settings"; \
    if [ -f /opt/agent-metadata/gh_config.json ]; then \
      host="$(jq -er '.hostname // "github.com"' /opt/agent-metadata/gh_config.json)"; \
      token="$(jq -er '.token' /opt/agent-metadata/gh_config.json)"; \
      printf '%s' "$token" | gh auth login --hostname "$host" --git-protocol https --with-token; \
      unset token; \
      gh auth setup-git; \
    fi; \
    if [ -f /opt/agent-metadata/tea_config.json ]; then \
      name="$(jq -er '.name // "default"' /opt/agent-metadata/tea_config.json)"; \
      url="$(jq -er '.url' /opt/agent-metadata/tea_config.json)"; \
      token="$(jq -er '.token' /opt/agent-metadata/tea_config.json)"; \
      tea logins add --name "$name" --url "$url" --token "$token" --no-version-check; \
      unset token; \
    fi

# This built-in prompt is an unmodified excerpt selected from AGENTS.md.demo.
RUN printf '%s\n' \
    '## Operating Principle' \
    '' \
    '- Investigate before acting. Build an accurate understanding from the repository itself rather than from names, assumptions, or generic technology patterns.' \
    '- Use the available tools to read, search, inspect, test, and verify. Browse relevant local and authoritative external documentation when the repository does not provide enough information, after checking that outbound data can be minimized and safely redacted.' \
    '- Keep project-specific knowledge evidence-driven. Do not pre-populate, preserve, or invent facts about languages, frameworks, directories, commands, workflows, conventions, or architecture.' \
    '- Leave project-specific details empty until they are needed and verified. Record only durable facts that help a future Agent work safely in this repository.' \
    '- Discover only the context required by the current task. Do not ask another Agent or user to complete a fixed questionnaire when the information can be determined by inspecting the repository.' \
    > /root/.pi/agent/AGENTS.md

RUN set -eu; \
    if [ -f /opt/agent-metadata/external.sh ]; then \
      bash /opt/agent-metadata/external.sh; \
    fi; \
    npm cache clean --force >/dev/null 2>&1 || true; \
    rm -f /root/.bash_history /root/.ash_history /root/.zsh_history; \
    rm -rf /root/.npm /var/lib/apt/lists/* /var/cache/apt/* /tmp/* /var/tmp/* /opt/agent-metadata

CMD ["sleep", "infinity"]
