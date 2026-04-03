# Nexus Assistant OS Premise

## What

Nexus Assistant OS is a Telegram-first Work OS with multi-agent
orchestration, multi-LLM support, and persistent memory. Deployed
as a Telegram bot over Firebase, it uses a state-machine architecture
(not an agent loop) where each message transitions structured state
in Firestore — making it predictable, auditable, and cost-controlled.
The system currently spans ~50 TypeScript files (~10,000 LOC) across
4 functional planes: Ingesta, Control, Ejecucion, and Persistencia.

## Who

Primary user today is the founder/solo operator managing complex
projects, proposals, research, and communications via Telegram.
Future target (H3) is B2B teams and organizations needing an
intelligent work OS integrated with Google Workspace, Slack, and
email — packaged as a multi-tenant SaaS product.

## Why

The current system is "ChatGPT in Telegram" — intelligent but
without memory and without safe external execution. Each conversation
starts from zero (~60 h/year lost repeating context), there is no
human approval mechanism for external actions (reputational risk),
no versioned artifact output, and 0 B2B revenue because the system
is not packageable. Two critical gaps block evolution: Project State
Engine (0% implemented) and Human-in-the-Loop Middleware (15%
implemented). 80% of the existing base is solid — evolution is
extension, not rewrite.

## Domain

Technology / SaaS / Productivity. Core domain concepts: multi-agent
orchestration, delegation modes (single, terna, committee), skill
system (24 skills, 96 workflows), constitution-governed behavior
(8 principles), circuit breaker fault tolerance, and semantic
memory with vector store. Key integrations: Telegram Bot API, Groq
(Llama 3), OpenRouter, Google Gemini, Whisper API, Firebase
(Functions, Firestore, Cloud Storage, Pub/Sub).

## Scope

**In scope**: Project State Engine, HIL Middleware completion,
artifact factory (versioned HTML proposals), cost intelligence
(token tracking per project), Google Workspace integration (Tasks,
Calendar), RAG improvements, observability/logging, and proactive
intelligence. The 3-horizon roadmap spans 16 weeks (~6 FTE-months).

**Out of scope for this discovery deliverable set**: actual
TypeScript implementation, Firebase console access, Telegram bot
runtime, and production deployment. This repository contains the
HTML deliverable suite (15 core documents + 8 annexes) produced
by the MAO Architecture Deep Dive discovery session that defines
the architecture, gaps, roadmap, and specifications for the above.
