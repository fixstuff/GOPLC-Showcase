# Preface {-}

This manual is the definitive reference for **GoPLC**, an IEC 61131-3 compliant programmable logic controller runtime written in Go. It is built from the same source of truth that ships embedded inside the running binary: every protocol guide, every hardware driver chapter, every whitepaper you are about to read is also available from the IDE's **Guides** menu on any running instance, and from the public documentation site at `goplc.app`.

GoPLC began as an experiment — could a modern garbage-collected language deliver the determinism, protocol breadth, and reliability demanded by industrial automation? Four months of AI-assisted development and roughly fifteen hundred built-in functions later, the answer is clearly yes. This manual tells the whole story: the architecture that makes sub-millisecond scan cycles possible, the fourteen industrial protocols that ship out of the box, the eight microcontroller targets that plug in over USB, and the visual IDE, AI assistant, and Node-RED integration that let engineers move from blank project to running controller in an afternoon.

## Who this manual is for {-}

Three audiences converge in these pages:

- **PLC programmers** coming from Rockwell, Siemens, Beckhoff, or Codesys who want to write Structured Text against a familiar IEC 61131-3 runtime — but with modern deployment, versioning, and integration affordances.
- **Software engineers** building control systems who want to understand the runtime as a Go application: its scheduling model, its protocol stacks, its extension points.
- **Systems integrators** sizing hardware, planning networks, and architecting distributed control for anything from a washing machine to a datacenter power room.

Wherever possible the writing stays concrete: real function signatures, real Structured Text examples, real configuration YAML, and real wire lists. The protocol chapters double as field references — print them out, staple them, and keep them on the cart.

## How this manual is organized {-}

The manual is divided into seven parts. Parts I and II introduce the runtime and the development environment; Part III documents every general-purpose function available to Structured Text code; Parts IV and V drill into hardware and industrial protocol support; Part VI covers the event bus and webhook delivery; and Part VII gathers the public technical whitepapers that explain the deeper design decisions behind the runtime.

You do not need to read this manual front to back. Start with **Getting Started** to install GoPLC and build your first program, skim the **IDE & Runtime** chapter to learn the development loop, then jump to whichever protocol or hardware chapter matches what you are trying to automate.

## Conventions {-}

- Built-in function names are rendered in `UPPER_SNAKE_CASE` monospace, for example `MB_READ_HOLDING` or `JSON_PARSE`.
- Function blocks (instantiated with a tag name) follow the IEC 61131-3 convention: `TON`, `CTU`, `PID`.
- Structured Text code appears in fenced blocks. Inline ST is set in monospace.
- Configuration YAML uses the same fenced-block style; paths and file names are in monospace.
- *Italicized* text signals a term of art or a placeholder to be filled in by the reader.

When a function's signature uses `name` as its first parameter, that name is a user-chosen label that identifies the instance for the rest of its lifetime — use the same name in every subsequent call to read, write, or delete it.

## Versioning {-}

This edition of the manual covers GoPLC 1.0.559 (April 2026). Because the content is assembled from the same guides that ship inside the binary, any running GoPLC instance newer than this edition will carry an updated copy of its own guides that supersedes the printed version for any drift. When in doubt, trust the IDE.
