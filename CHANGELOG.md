# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-02-21

### Added

- DOT parser with full lexer, support for digraphs, subgraphs, and attribute blocks
- 9 node types: start, exit, codergen, conditional, wait.human, parallel, fan_in, tool, manager_loop
- LLM backends: simulation (dry-run) and Claude Code (`claude --print`)
- Human approval gates with accelerator key notation
- Conditional branching with `=` and `!=` operators on edges
- Parallel fan-out/fan-in with configurable join policies and concurrency limits
- Retry policies with exponential backoff and jitter
- Goal gate enforcement at exit nodes with retry-to-target
- Checkpoint/resume for interrupted or failed runs
- Model stylesheets: CSS-like DSL for LLM configuration per node
- Variable expansion (`$goal`) in prompts
- 13 built-in validation/lint rules
- Thread-safe context with `Concurrent::ReadWriteLock`
- Event emitter for monitoring pipeline execution
- CLI via Thor: `attractor run` and `attractor validate`
