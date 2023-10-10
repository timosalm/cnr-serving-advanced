FROM ghcr.io/vmware-tanzu-labs/educates-jdk17-environment:2.6.15

USER root

RUN curl -L -o /tmp/kn https://github.com/knative/client/releases/download/knative-v1.11.0/kn-linux-amd64 \
    && mv /tmp/kn /usr/local/bin/kn \
    && chmod 755 /usr/local/bin/kn

USER 1001

RUN fix-permissions /home/eduk8s
