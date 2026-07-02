# Sandbox

The ZeroBias tools need to be able to create and manage containers for tasks such as locally hosting the registry. If you wish to run the tools from within a sandbox, the tools must have the ability to reach outside the sandbox to the host's Docker environment.

## Pre-Built

The [AuditCrowd Sandbox](https://github.com/auditcrowd/sandbox) was created to run the ZeroBias tools from within a Docker container. Consider using this if it meets your needs.

## Roll Your Own

If you wish run the ZeroBias tools within your own Docker container, the configuration must enable tools inside the container to start, interact with, and stop containers in the host's Docker environment. 

This requires the following:  

    - docker-ce-cli (Must be installed as root in the Dockerfile)
    - docker-compose-plugin (Must be installed as root in the Dockerfile)
    - Socket mount `/var/run/docker.sock:/var/run/docker.sock`

_Do NOT use docker.io from Debian repos — it lacks `docker compose` (v2)._

### Dockerfile Configuration

Ensure your Dockerfile includes the following:

```dockerfile
USER root
RUN curl -fsSL https://download.docker.com/linux/debian/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       docker-ce-cli \
       docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*
```

### Docker Compose Configuration

Ensure your `docker-compose.yml` includes the following:

```bash
  # compose.yml
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
  # or
  # docker run
  docker run ... -v /var/run/docker.sock:/var/run/docker.sock ...
``
