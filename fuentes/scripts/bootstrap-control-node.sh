#!/usr/bin/env bash
# Instala en el nodo de control (hoy, la propia VPS) las herramientas de IaC con
# versiones FIJADAS y verificación SHA256 contra el fichero de sumas del release.
# Idempotente. Requiere sudo (SUDO_ASKPASS definido o sudo sin contraseña).
#
# Doble comprobación de cada binario:
#   1) contra la suma SHA256 que publica el propio release (detecta corrupción), y
#   2) contra los hashes FIJADOS en scripts/bootstrap-checksums.txt, que viven en este
#      repositorio y se revisan en cada cambio (detecta un release alterado a posteriori).
# Para subir una versión: cambia la variable, ejecuta
#   BOOTSTRAP_PRINT_PINS=1 PINS_OUT=/ruta/pins.txt scripts/bootstrap-control-node.sh
# y revisa/sustituye las líneas nuevas en bootstrap-checksums.txt.
#
# Pendiente (ver docs/infraestructura/excepciones.md): verificar firmas cosign/GPG donde el
# proyecto las publique, y fijar con hashes las dependencias transitivas de pip.
set -euo pipefail

# --- Versiones fijadas: se actualizan por PR (Renovate), nunca con "latest" --------
TOFU_VERSION=1.13.1
SOPS_VERSION=3.13.3
KUBECONFORM_VERSION=0.8.0
GITLEAKS_VERSION=8.30.1
TFLINT_VERSION=0.64.0
FLUX_VERSION=2.9.6
HELM_VERSION=4.3.1
KUBECTL_VERSION=1.36.5      # misma rama menor que el canal "stable" de k3s
ANSIBLE_CORE_VERSION=2.21.5
ANSIBLE_LINT_VERSION=26.10.1
PRE_COMMIT_VERSION=4.7.0
YAMLLINT_VERSION=1.38.0
# -------------------------------------------------------------------------------

SUDO="sudo"
[ -n "${SUDO_ASKPASS:-}" ] && SUDO="sudo -A"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PINS_FILE="${BOOTSTRAP_PINS_FILE:-$ROOT_DIR/scripts/bootstrap-checksums.txt}"

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/cenit-bootstrap"
mkdir -p "$CACHE"
WORK="$(mktemp -d "$CACHE/run.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Solo HTTPS (también en las redirecciones) y TLS >= 1.2.
fetch() { curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL --retry 3 --retry-delay 2 -o "$2" "$1"; }

# pin_check <directorio> <fichero>: compara con el hash fijado en el repositorio
# (o, con BOOTSTRAP_PRINT_PINS=1, lo añade a PINS_OUT para revisarlo).
pin_check() {
  local dir=$1 file=$2
  if [ "${BOOTSTRAP_PRINT_PINS:-0}" = "1" ]; then
    (cd "$dir" && sha256sum "$file") >> "${PINS_OUT:?Define PINS_OUT con BOOTSTRAP_PRINT_PINS=1}"
    return 0
  fi
  if ! (cd "$dir" && grep -E "[[:space:]*]${file}\$" "$PINS_FILE" | sha256sum -c -); then
    echo "ERROR: ${file} no coincide con el hash fijado en ${PINS_FILE} (o no tiene entrada)." >&2
    return 1
  fi
}

# get_verified <dir> <url> <sums_url>: descarga y verifica en un directorio nuevo.
get_verified() {
  local dir=$1 url=$2 sums_url=$3 file sums
  file="$(basename "$url")"
  sums="$(basename "$sums_url")"
  mkdir -p "$dir"
  fetch "$url" "$dir/$file"
  fetch "$sums_url" "$dir/$sums"
  (cd "$dir" && grep -E "[[:space:]*]${file}\$" "$sums" | sha256sum -c -)
  pin_check "$dir" "$file"
}

gh() { echo "https://github.com/$1/releases/download/$2"; }

echo "== paquetes de apt =="
$SUDO apt-get update -qq
$SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
  python3-venv pipx age lynis shellcheck unzip git jq curl ca-certificates gnupg

echo "== OpenTofu ${TOFU_VERSION} =="
d="$WORK/tofu"
get_verified "$d" \
  "$(gh opentofu/opentofu "v${TOFU_VERSION}")/tofu_${TOFU_VERSION}_linux_amd64.zip" \
  "$(gh opentofu/opentofu "v${TOFU_VERSION}")/tofu_${TOFU_VERSION}_SHA256SUMS"
(cd "$d" && unzip -q -o "tofu_${TOFU_VERSION}_linux_amd64.zip" tofu)
$SUDO install -m 0755 "$d/tofu" /usr/local/bin/tofu

echo "== SOPS ${SOPS_VERSION} =="
d="$WORK/sops"
get_verified "$d" \
  "$(gh getsops/sops "v${SOPS_VERSION}")/sops-v${SOPS_VERSION}.linux.amd64" \
  "$(gh getsops/sops "v${SOPS_VERSION}")/sops-v${SOPS_VERSION}.checksums.txt"
$SUDO install -m 0755 "$d/sops-v${SOPS_VERSION}.linux.amd64" /usr/local/bin/sops

echo "== kubeconform ${KUBECONFORM_VERSION} =="
d="$WORK/kubeconform"
get_verified "$d" \
  "$(gh yannh/kubeconform "v${KUBECONFORM_VERSION}")/kubeconform-linux-amd64.tar.gz" \
  "$(gh yannh/kubeconform "v${KUBECONFORM_VERSION}")/CHECKSUMS"
(cd "$d" && tar -xzf kubeconform-linux-amd64.tar.gz kubeconform)
$SUDO install -m 0755 "$d/kubeconform" /usr/local/bin/kubeconform

echo "== gitleaks ${GITLEAKS_VERSION} =="
d="$WORK/gitleaks"
get_verified "$d" \
  "$(gh gitleaks/gitleaks "v${GITLEAKS_VERSION}")/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
  "$(gh gitleaks/gitleaks "v${GITLEAKS_VERSION}")/gitleaks_${GITLEAKS_VERSION}_checksums.txt"
(cd "$d" && tar -xzf "gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" gitleaks)
$SUDO install -m 0755 "$d/gitleaks" /usr/local/bin/gitleaks

echo "== tflint ${TFLINT_VERSION} =="
d="$WORK/tflint"
get_verified "$d" \
  "$(gh terraform-linters/tflint "v${TFLINT_VERSION}")/tflint_linux_amd64.zip" \
  "$(gh terraform-linters/tflint "v${TFLINT_VERSION}")/checksums.txt"
(cd "$d" && unzip -q -o tflint_linux_amd64.zip tflint)
$SUDO install -m 0755 "$d/tflint" /usr/local/bin/tflint

echo "== Flux CLI ${FLUX_VERSION} =="
d="$WORK/flux"
get_verified "$d" \
  "$(gh fluxcd/flux2 "v${FLUX_VERSION}")/flux_${FLUX_VERSION}_linux_amd64.tar.gz" \
  "$(gh fluxcd/flux2 "v${FLUX_VERSION}")/flux_${FLUX_VERSION}_checksums.txt"
(cd "$d" && tar -xzf "flux_${FLUX_VERSION}_linux_amd64.tar.gz" flux)
$SUDO install -m 0755 "$d/flux" /usr/local/bin/flux

echo "== Helm ${HELM_VERSION} =="
d="$WORK/helm"
get_verified "$d" \
  "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
  "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256sum"
(cd "$d" && tar -xzf "helm-v${HELM_VERSION}-linux-amd64.tar.gz" --strip-components=1 linux-amd64/helm)
$SUDO install -m 0755 "$d/helm" /usr/local/bin/helm

echo "== kubectl ${KUBECTL_VERSION} =="
d="$WORK/kubectl"
mkdir -p "$d"
fetch "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" "$d/kubectl"
fetch "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256" "$d/kubectl.sha256"
(cd "$d" && echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c -)
pin_check "$d" kubectl
$SUDO install -m 0755 "$d/kubectl" /usr/local/bin/kubectl

echo "== Python (pipx): ansible-core, ansible-lint, pre-commit, yamllint =="
export PIPX_HOME="$HOME/.local/pipx" PIPX_BIN_DIR="$HOME/.local/bin"
export PATH="$PIPX_BIN_DIR:$PATH"
pipx install --force "ansible-core==${ANSIBLE_CORE_VERSION}"
pipx install --force "ansible-lint==${ANSIBLE_LINT_VERSION}"
pipx install --force "pre-commit==${PRE_COMMIT_VERSION}"
pipx install --force "yamllint==${YAMLLINT_VERSION}"
pipx ensurepath >/dev/null

# Una versión anterior creaba enlaces en /usr/local/bin hacia código escribible por admin
# (que root habría ejecutado por el secure_path de sudo). Se retiran si existen.
for tool in ansible ansible-playbook ansible-galaxy ansible-vault ansible-lint pre-commit yamllint; do
  if [ -L "/usr/local/bin/$tool" ]; then $SUDO rm -f "/usr/local/bin/$tool"; fi
done

echo "== Colecciones de Ansible (versiones fijadas en ansible/requirements.yml) =="
"$PIPX_BIN_DIR/ansible-galaxy" collection install -r "$ROOT_DIR/ansible/requirements.yml"

echo "== Versiones instaladas =="
# sed -n '1p' lee toda la entrada: evita el SIGPIPE que `head -1` provoca con pipefail.
first_line() { "$@" 2>&1 | sed -n '1p'; }
first_line tofu version
first_line sops --version
first_line age --version
first_line kubeconform -v
first_line gitleaks version
first_line tflint --version
first_line flux --version
first_line helm version --short
first_line kubectl version --client
first_line ansible --version
first_line ansible-lint --version
first_line pre-commit --version
first_line yamllint --version
first_line lynis --version
shellcheck --version | sed -n '2p'
