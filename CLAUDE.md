# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

This directory contains the **HTML deliverable suite** from a MetodologIA Architecture Deep Dive discovery session for **Nexus Assistant OS** (a Telegram-first Work OS / Pristino). The discovery was executed on 2026-04-02 using the MAO (MetodologIA Agentic Orchestrator) framework.

## Document Structure

The deliverables follow a numbered pipeline sequence:

- **00-08**: Core discovery pipeline (Discovery Plan → Stakeholder Map → AS-IS Brief → AS-IS Analysis → Flow Mapping → Scenarios/Feasibility → Solution Roadmap → Functional Spec → Executive Pitch)
- **10-14**: Findings suite (Presentation → Technical Findings → Functional Findings → Business Review → AI Opportunities)
- **A1-A10**: Annexes (Cross-Document Reconciliation → Gap Analysis Heat Map → TO-BE Architecture → ADRs → Canonical Data Model → 3-Horizon Roadmap → Risk Register → Executive Summary)

Each HTML file is **self-contained** — all CSS, fonts (Google Fonts via CDN), and content are embedded inline. No build step or external assets required.

## Design System

All files share a consistent MetodologIA brand system:
- **Color palette**: `--bg-body: #1E3258`, `--gold: #FFD700`, `--blue: #137DC5`, `--purple: #BBA0CC`
- **Typography**: Poppins (display), Montserrat (body), Trebuchet MS (footnotes)
- **Pattern**: Glass-morphism cards with `rgba(255,255,255,0.06)` backgrounds and `backdrop-filter: blur()`
- **Evidence tags**: `[CODIGO]`, `[CONFIG]`, `[DOC]`, `[INFERENCIA]`, `[SUPUESTO]` — color-coded inline badges

## Plugin Context

- **Discovery plugin**: MAO (`/mao:` prefix)
- **Project plugin**: PM (`/pm:` prefix)
- Source markdown and discovery session log live in the parent directory (`../DISCOVERY_ARCHITECTURE_DEEP_DIVE.md`)

## Working With These Files

- To preview: open any `.html` file directly in a browser — no server needed
- To edit content: modify HTML directly; there is no markdown-to-HTML pipeline in this directory
- To maintain brand consistency when adding/editing files: match the CSS custom properties defined in `:root` and use the same Google Fonts imports
- The `data-mtia` attributes on HTML elements are MetodologIA semantic markers for traceability

@AGENTS.md
