FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/libreturks/kubeutils"
LABEL org.opencontainers.image.path="Dockerfile"
LABEL org.opencontainers.image.title="kubeutils"
LABEL org.opencontainers.image.description="Minimal Image for Kubernetes Workloads"
LABEL org.opencontainers.image.authors="Yağız (saveside), Taha (mt190502)"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.documentation="https://github.com/libreturks/kubeutils/README.md"

ARG TARGETARCH
ARG TARGETPLATFORM
ARG RUNNER_VERSION=2.331.0
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.8.1

ENV UID=1000
ENV GID=0
ENV SOPS_VERSION=v3.11.0
ENV HELM_VERSION=v4.1.1
ENV KUBECONFORM_VERSION=v0.7.0
ENV PLUTO_VERSION=v5.22.7
ENV KUBE_LINTER_VERSION=v0.8.1

RUN useradd -G 0 runner
ENV HOME /home/runner

RUN mkdir -p /home/runner \
    && chown -R runner:$GID /home/runner
WORKDIR /home/runner

RUN apt update -y && apt install -y jq git curl unzip

RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) KUBE_LINTER_BIN="kube-linter-linux" ;; \
      arm64) KUBE_LINTER_BIN="kube-linter-linux_arm64" ;; \
      *) echo "Unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    PLUTO_VERSION_NO_V=$(echo "${PLUTO_VERSION}" | sed 's/^v//'); \
    \
    curl -fsSL https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar zxf - -C /usr/local/bin/ --strip-components 1 linux-amd64/helm \
    && curl -fsSL https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.${TARGETARCH} -o /usr/local/bin/sops \
    && curl -fsSL https://github.com/stackrox/kube-linter/releases/download/${KUBE_LINTER_VERSION}/${KUBE_LINTER_BIN} -o /usr/local/bin/kube-linter \
    && curl -fsSL https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-${TARGETARCH}.tar.gz | tar -xz -C /usr/local/bin kubeconform \
    && curl -fsSL https://github.com/FairwindsOps/pluto/releases/download/${PLUTO_VERSION}/pluto_${PLUTO_VERSION_NO_V}_linux_${TARGETARCH}.tar.gz | tar -xz -C /usr/local/bin pluto \
    && curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/*

RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "amd64" ]; then export ARCH=x64 ; fi \
    && curl -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz \
    && bash ./bin/installdependencies.sh \
    && apt-get clean

RUN curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm runner-container-hooks.zip

USER runner
