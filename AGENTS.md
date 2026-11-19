# AGENTS.md — ImagenCIInfraestructura

Imagen de contenedor con las herramientas de la CI de `Cenit-Digital/KubernetesInfrastructure`. El detalle está en `README.md`.

- Versiones y SHA256 siempre fijados. `fuentes/` solo se actualiza con `scripts/sincronizar.sh`, nunca a mano.
- Sin root al ejecutarse (uid 1001, gid 123) y sin secretos ni nada interno.

## Diseño

Este repo no tiene interfaz y la imagen no lleva el CLI de Impeccable: la CI de KubernetesInfrastructure no analiza
ninguna web. Toda interfaz de la organización se diseña y se revisa con la skill **Impeccable**, que sustituye a Claude
Design y a `frontend-design`. Su detector corre en los repos web con la plantilla `Cenit-Digital/TemplateSSDUncleBob`
v0.5.0 o posterior (`docs/impeccable.md`).
