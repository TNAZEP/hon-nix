{ inputs, ... }:
{
  flake.nixosModules.ai = { lib, pkgs, ... }: {
    imports = [ inputs.self.nixosModules.docker ];

    services.ollama = {
      enable = true;
      # Vulkan supports Midgar's RX 9070 XT through the existing Mesa stack.
      package = pkgs.ollama-vulkan;
      host = "127.0.0.1";
      port = 11434;
    };

    # Upstream deployment reference:
    # https://github.com/odysseus-dev/odysseus/blob/main/docker-compose.yml
    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        odysseus = {
          # Official main-channel image, pinned to its linux/amd64 manifest.
          image = "ghcr.io/odysseus-dev/odysseus@sha256:dc080ce7ba5db3f2b8e015e2ffc0df942e960e49e93600de841f730b8ffa6bcc";
          dependsOn = [
            "odysseus-chromadb"
            "odysseus-searxng"
          ];
          # Host networking reaches loopback-only Ollama without exposing its API.
          extraOptions = [ "--network=host" ];
          cmd = [
            "uvicorn"
            "app:app"
            "--host"
            "127.0.0.1"
            "--port"
            "7011"
          ];
          environment = {
            OLLAMA_BASE_URL = "http://127.0.0.1:11434";
            LLM_HOST = "127.0.0.1:11434";
            SEARXNG_INSTANCE = "http://127.0.0.1:8080";
            CHROMADB_HOST = "127.0.0.1";
            CHROMADB_PORT = "8100";
            AUTH_ENABLED = "true";
            LOCALHOST_BYPASS = "false";
            ALLOWED_ORIGINS = "http://localhost:7011,http://127.0.0.1:7011";
            ANONYMIZED_TELEMETRY = "FALSE";
          };
          volumes = [
            "odysseus-data:/app/data"
            "odysseus-logs:/app/logs"
            "odysseus-ssh:/app/.ssh"
            "odysseus-huggingface:/app/.cache/huggingface"
            "odysseus-local:/app/.local"
          ];
        };
        odysseus-chromadb = {
          image = "docker.io/chromadb/chroma:1.5.9@sha256:1e0b73a187a28757c572acba508c46f48c9e8b0acaf5c20e6d95cdedce1acdf6";
          ports = [ "127.0.0.1:8100:8000" ];
          volumes = [ "odysseus-chromadb:/data" ];
          environment.ANONYMIZED_TELEMETRY = "FALSE";
        };
        odysseus-searxng = {
          image = "docker.io/searxng/searxng:2026.10.24-ef0ec03da@sha256:7c7cbe509429e82755104b2a95f52085a98633c95d53f44e4e905fa3a59f08c8";
          ports = [ "127.0.0.1:8080:8080" ];
          volumes = [ "odysseus-searxng:/etc/searxng" ];
          environment.SEARXNG_BASE_URL = "http://localhost:8080/";
          entrypoint = "/bin/sh";
          cmd = [
            "-c"
            ''
              set -eu
              if [ ! -s /etc/searxng/settings.yml ]; then
                python -c 'import pathlib,secrets; pathlib.Path("/etc/searxng/settings.yml").write_text("use_default_settings: true\nserver:\n  secret_key: " + secrets.token_urlsafe(48) + "\nsearch:\n  formats: [html, json]\n")'
              fi
              exec /usr/local/searxng/entrypoint.sh
            ''
          ];
          extraOptions = [
            "--cap-drop=ALL"
            "--cap-add=CHOWN"
            "--cap-add=SETGID"
            "--cap-add=SETUID"
            "--cap-add=DAC_OVERRIDE"
            "--health-cmd=python -c \"import urllib.request; urllib.request.urlopen('http://localhost:8080/', timeout=5).read(1)\""
            "--health-interval=5s"
            "--health-timeout=6s"
            "--health-retries=20"
            "--health-start-period=10s"
          ];
        };
      };
    };

    systemd.services.docker-odysseus = {
      wants = [ "ollama.service" ];
      after = [ "ollama.service" ];
      # OCI dependsOn orders startup; wait for the HTTP services to be ready too.
      preStart = ''
        ready=false
        for attempt in $(${pkgs.coreutils}/bin/seq 1 120); do
          if ${pkgs.curl}/bin/curl -fsS --max-time 2 http://127.0.0.1:11434/api/tags >/dev/null \
            && ${pkgs.curl}/bin/curl -fsS --max-time 2 http://127.0.0.1:8080/ >/dev/null \
            && ${pkgs.curl}/bin/curl -fsS --max-time 2 http://127.0.0.1:8100/api/v2/heartbeat >/dev/null; then
            ready=true
            break
          fi
          ${pkgs.coreutils}/bin/sleep 2
        done
        if [ "$ready" != true ]; then
          echo "Ollama or Odysseus dependencies did not become ready" >&2
          exit 1
        fi
      '';
      serviceConfig.TimeoutStartSec = lib.mkForce "15min";
    };
  };
}
