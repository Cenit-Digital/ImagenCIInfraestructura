# ImagenCIInfraestructura

Imagen de contenedor con las herramientas de la CI de `Cenit-Digital/KubernetesInfrastructure` (repo privado), para ejecutarla en
los runners propios de la organización (`cenit-runners`, ARC en modo `kubernetes`) cuando se agota el cupo de GitHub Actions
(issue KubernetesInfrastructure#68).

- `ghcr.io/cenit-digital/ci-infraestructura:sha-<commit>`, siempre por digest, nunca `latest`.
- Sin root ni `sudo` al ejecutarse (uid 1001, gid 123), como exige Pod Security `restricted`.
- Las herramientas las instala `fuentes/scripts/bootstrap-control-node.sh`, copia exacta del script del repo privado, con versiones y SHA256 fijados. Sin nada interno ni secretos.
- `fuentes/` se actualiza con `scripts/sincronizar.sh <ruta de KubernetesInfrastructure>`. La CI del repo privado compara `/opt/cenit-ci/fuentes.sha256` con sus ficheros y falla si la imagen se quedó atrás.
- Repo **público**: sus minutos de Actions no cuentan para el cupo. El paquete de GHCR nace privado: hay que ponerlo en público (Package settings → Change visibility) para que los runners lo descarguen sin credenciales.
