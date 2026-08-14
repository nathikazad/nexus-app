# Nexus Docs architecture

The canonical architecture overview lives in the project
[`README.md`](../README.md). This document records the dependency direction in
more detail.

## Product narrative

```text
app
  -> account
  -> workspace
       -> library
       -> documents
            -> books
            -> tags
            -> companion
            -> publishing
  -> sync
  -> settings
```

`workspace` coordinates the responsive experience but does not own document
storage. `documents` owns application-ready document vocabulary and editing.
`library` owns finding documents. `sync` owns persistence mechanics and selects
native versus web implementations.

## Data direction

```text
KGQL structs -> document mapper -> document models -> workflow -> UI
Drift rows    -> local mapper    -> document models -> workflow -> UI
```

Backend structs and Drift rows must not appear in UI signatures. Document,
sync, book, and tag models remain independent of Flutter and infrastructure.

## Composition

Production wiring belongs to the capability that owns the resulting object.
There is no global composition folder:

- account providers restore or invalidate identity;
- sync providers construct Drift, transports, the uploader, and supervisor;
- workspace providers choose native or web document workspaces;
- document providers open sessions and assemble document services;
- library providers expose catalog and search streams;
- publishing providers assemble publishing and mirror services.

Platform variation is selected at these assembly boundaries. Product widgets
must not scatter native/web conditionals.

## Source-size heuristic

Handwritten production files should normally contain 50–1000 lines. Tiny
facades, entrypoints, contracts, and platform stubs are allowed when they make
a real boundary clearer. Generated files are exempt. A file over 1000 lines is
an architecture failure and is rejected by the narrative boundary test.
