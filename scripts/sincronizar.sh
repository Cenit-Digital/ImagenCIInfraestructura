#!/usr/bin/env bash
# Copia en fuentes/ los ficheros del repo privado de los que sale la imagen. Uso: scripts/sincronizar.sh <ruta de KubernetesInfrastructure>
# Tras sincronizar, PR aquí; al fusionarlo se publica la imagen y su referencia (con digest) se copia a harness-ci.yml allí.
set -euo pipefail
ki="${1:?Uso: $0 <ruta de KubernetesInfrastructure>}"
cd "$(dirname "$0")/.."
install -m 0755 "$ki/scripts/bootstrap-control-node.sh" fuentes/scripts/bootstrap-control-node.sh
install -m 0644 "$ki/scripts/bootstrap-checksums.txt" fuentes/scripts/bootstrap-checksums.txt
install -m 0644 "$ki/ansible/requirements.yml" fuentes/ansible/requirements.yml
git status --short fuentes/
