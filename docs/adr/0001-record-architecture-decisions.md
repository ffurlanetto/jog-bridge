# 0001. Record architecture decisions

- Status: Accepted
- Date: 2026-10-21

## Context

The project rests on choices that cannot be guessed from reading the code: userspace USB access,
static linking, LEDs through control transfers, unsigned distribution. Without a written
trace, they risk being "fixed" by mistake.

## Decision

We record every structural decision in `docs/adr/`, following the [template](template.md), one
file per decision, numbered in order.

## Consequences

- Contributors (and coding agents) find the *why* in one place.
- A decision is changed by adding an ADR, not by rewriting history.
- A small writing cost for each structural change.
