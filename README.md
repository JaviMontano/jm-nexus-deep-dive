<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:122562,100:BBA0CC&height=220&section=header&text=Nexus%20Architecture%20Deep%20Dive&fontSize=40&fontColor=FFD700&fontAlignY=35&desc=Discovery%20arquitect%C3%B3nico%20completo%20con%20MAO%20%2B%20SDD&descSize=18&descColor=ffffff&descAlignY=55" alt="Nexus Deep Dive Banner" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/versión-1.0.0-137DC5?style=for-the-badge" alt="Versión" />
  <img src="https://img.shields.io/badge/licencia-MIT-122562?style=for-the-badge" alt="Licencia" />
  <img src="https://img.shields.io/badge/entregables-24-FFD700?style=for-the-badge" alt="Entregables" />
  <img src="https://img.shields.io/badge/pipeline-completo-BBA0CC?style=for-the-badge" alt="Pipeline" />
</p>

---

## Acerca de Nexus Architecture Deep Dive

**Nexus Architecture Deep Dive** es un ejercicio de deep dive arquitectónico ejecutado con el ecosistema MAO + SDD. Incluye 24 entregables HTML: desde plan de discovery y mapeo de stakeholders hasta roadmap de solución y handover operativo.

Este repositorio sirve como ejemplo real del pipeline MetodologIA en acción, demostrando cómo los plugins trabajan en conjunto para producir un análisis arquitectónico completo.

---

## Características principales

- **24 entregables HTML interactivos** — Cada uno autocontenido con navegación interna
- **Pipeline completo de discovery ejecutado** — Del plan inicial al handover final
- **Plan de discovery → Stakeholder map → AS-IS → Flujos → Escenarios → Roadmap → Handover** — Secuencia completa
- **Arquitectura TO-BE con ADRs** — Decisiones arquitectónicas documentadas y trazables
- **Gap Analysis Heat Map** — Visualización de brechas entre estado actual y objetivo
- **Risk Register** — Registro de riesgos con impacto y mitigación
- **Reconciliación cross-document** — Consistencia verificada entre los 24 entregables

---

## Instalación

```bash
# Clonar el repositorio
git clone https://github.com/JaviMontano/jm-nexus-deep-dive.git
cd jm-nexus-deep-dive

# Abrir los HTML directamente en el navegador
open entregables/01_discovery_plan.html
```

---

## Entregables incluidos

| # | Entregable | Descripción |
|---|-----------|-------------|
| 01 | Plan de Discovery | Alcance, objetivos y cronograma |
| 02 | Stakeholder Map | Mapa de interesados con influencia e interés |
| 03 | AS-IS Architecture | Estado actual de la arquitectura |
| 04 | Flujos de Proceso | Mapeo de flujos críticos del negocio |
| 05 | Análisis de Escenarios | Evaluación de alternativas arquitectónicas |
| 06 | Gap Analysis | Brechas entre AS-IS y TO-BE |
| 07 | Heat Map | Visualización de criticidad por componente |
| 08 | Risk Register | Riesgos con probabilidad, impacto y mitigación |
| 09 | ADRs | Architecture Decision Records |
| 10 | TO-BE Architecture | Arquitectura objetivo propuesta |
| 11-20 | Entregables complementarios | Análisis de datos, seguridad, integraciones, rendimiento |
| 21 | Roadmap de Solución | Plan de implementación por fases |
| 22 | Estimación de Esfuerzo | FTE-meses por componente |
| 23 | Reconciliación Cross-Document | Verificación de consistencia |
| 24 | Handover Operativo | Paquete de transferencia al equipo |

---

## Pipeline utilizado

```
MAO Discovery          SDD Specification        Síntesis
┌───────────┐       ┌───────────┐       ┌───────────┐
│Stakeholders│       │  Specify  │       │  Roadmap  │
│AS-IS       │  →    │  Design   │  →    │  Handover │
│Flujos      │       │  Decide   │       │  ADRs     │
│Gaps        │       │  Validate │       │  Reconcil.│
└───────────┘       └───────────┘       └───────────┘
```

---

## Parte del Ecosistema MetodologIA / JM Labs

Este deep dive fue producido con las herramientas del ecosistema:

| Repositorio | Descripción |
|-------------|-------------|
| [mao-discovery-framework](https://github.com/JaviMontano/mao-discovery-framework) | Framework de discovery utilizado para las fases iniciales |
| [mao-sdd](https://github.com/JaviMontano/mao-sdd) | Specification-Driven Development para la fase de diseño |
| [mao-sovereign-architect](https://github.com/JaviMontano/mao-sovereign-architect) | Agentes de arquitectura para las decisiones técnicas |
| [jm-adk-alfa](https://github.com/JaviMontano/jm-adk-alfa) | Kit de desarrollo agéntico que orquestó el pipeline |

---

## Licencia

Este proyecto está licenciado bajo **MIT**. Consulta el archivo [LICENSE](LICENSE) para más detalles.

---

<p align="center">
  Creado por <a href="https://github.com/JaviMontano">Javier Montaño</a> · JM Labs / MetodologIA · MIT
</p>

<p align="center">
  <img src="https://capsule-render.vercel.app/api?type=waving&color=0:122562,100:BBA0CC&height=120&section=footer" alt="Footer" />
</p>
