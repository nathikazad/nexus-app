# nx_live_agent

Reusable live voice-session infrastructure for Nexus Flutter apps. The package
owns the Realtime transport, session lifecycle, event normalization, tool
dispatch, microphone state, and credential boundary. It does not know about
flashcards, notes, documents, or KGQL models.

An app supplies three things:

1. A `LiveAgentSpec` containing domain instructions and initial anchor context.
2. A list of `LiveAgentTool`s implementing domain actions.
3. A `LiveAgentCredentialProvider`.

`nx_cards` currently supplies card context and the tools
`assess_current_card`, `get_current_examples`, and `advance_card`. A future
`nx_notes` integration can use the same session with document context and tools
such as `get_document_section` without changing this package.

Production clients should implement `LiveAgentCredentialProvider` by requesting
a short-lived credential from a Nexus server endpoint. The existing static
provider is retained for local development and keeps that later change outside
the app coordinator.
