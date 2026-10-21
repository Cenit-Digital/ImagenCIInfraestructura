# Imagen de la CI de Cenit-Digital/KubernetesInfrastructure para los runners propios (cenit-runners, ARC en modo
# kubernetes): el pod de trabajo corre sin root ni sudo (Pod Security restricted, uid 1001 / gid 123), así que las
# herramientas no se pueden instalar en el job y vienen aquí, instaladas por el MISMO scripts/bootstrap-control-node.sh
# (versiones y SHA256 fijados) que usa la máquina de control. fuentes/ es una copia exacta de esos ficheros: la CI del repo
# privado comprueba /opt/cenit-ci/fuentes.sha256 contra los suyos y falla si la imagen se quedó atrás.
# Sin nada interno ni secretos: solo herramientas públicas (ADR 0012 D8b, regla R1).
FROM ubuntu:24.04@sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac

ARG DEBIAN_FRONTEND=noninteractive
# El bootstrap instala pipx y las colecciones de Ansible bajo $HOME: se fija en una ruta del sistema legible por todos.
ENV HOME=/opt/cenit-ci

# sudo solo durante la construcción: el bootstrap lo invoca y aquí corre como root. python3-yaml lo usan verify.sh y los tests.
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends sudo ca-certificates curl python3-yaml \
 && rm -rf /var/lib/apt/lists/*

COPY fuentes/ /opt/cenit-ci/fuentes/

RUN /opt/cenit-ci/fuentes/scripts/bootstrap-control-node.sh \
 && cd /opt/cenit-ci/fuentes \
 && sha256sum scripts/bootstrap-control-node.sh scripts/bootstrap-checksums.txt ansible/requirements.yml > /opt/cenit-ci/fuentes.sha256 \
 && apt-get purge -y -qq sudo \
 && apt-get autoremove -y -qq \
 && rm -rf /var/lib/apt/lists/* /opt/cenit-ci/.cache \
 && groupadd -g 123 ci \
 && useradd -u 1001 -g 123 -M -d /tmp -s /bin/bash ci \
 && chmod -R a+rX /opt/cenit-ci

ENV PATH=/opt/cenit-ci/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    ANSIBLE_COLLECTIONS_PATH=/opt/cenit-ci/.ansible/collections \
    HOME=/tmp

USER 1001:123
WORKDIR /tmp
