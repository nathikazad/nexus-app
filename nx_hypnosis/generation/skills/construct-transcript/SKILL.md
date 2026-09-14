---
name: nx-hypnosis-script-gen
description: Write or revise personal hypnosis and visualization transcripts for NX Hypnosis around a person's chosen desires and identity. Use for transcript work before voice generation.
---

Create a spoken transcript that helps the listener rehearse a freely chosen identity through a concrete, emotionally meaningful experience. Use the user's desires, values, and feedback as the brief. Do not generate audio or write to the database unless that work is also requested.

For a requested third-person character story with dialogue and a cast, use [the story construction skill](../construct-story/SKILL.md); its narrative format supersedes the first-person/second-person preferences below.

## Gather the brief

Use the conversation for the desired belief, current self-reported experience, perspective, length, and relevant personal details. Ask only for missing information that materially changes the script. When the user requests using stored desires, resolve their account to its Person and associated desires; do not assume the most recent tape or hardcode account IDs.

Distinguish the desired identity from the person's reported current circumstances. Within a clearly understood visualization, depict the desired life in the present tense. Do not present imagined earnings, testimonials, health outcomes, or relationships as verified real events outside the transcript.

## Writing approach

The preferred format from this project is:

- A short, permissive relaxation opening, approximately 20–30 seconds when spoken with pauses. Invite a comfortable posture, relaxed shoulders/jaw, and an easy breath. Keep it simple.
- Flow directly into the experience without announcing that a story, visualization, or identity exercise is about to begin. Keep the engineering explanation outside the spoken text. This is an immersive presentation choice, not permission for covert persuasion or fabricated memories.
- Usually address the listener as “you.” Use first person when requested, and avoid switching perspectives accidentally. Do not invent a protagonist's name.
- Depict the chosen identity as already embodied within the scene, rather than as a distant possibility the protagonist merely imagines. Connect identity to choices, action, useful contributions, and the lived benefits of those actions.
- Return to the core belief throughout with varied, grounded reinforcement. Avoid a detached third-person biography or a list of affirmations with no supporting experience.
- Include concrete details only when they establish impact, agency, security, freedom, or the chosen value. Avoid decorative details about unrelated people's routines.
- If messages or testimonials appear in the visualization, keep them short. Focus on how the listener's work helps people act toward their own desires, rather than spending a large portion of the narration reading praise.
- End with a quiet integration of the identity. Match a rest/sleep or wakeful ending to the requested use; do not add an abrupt energetic ending to a relaxation tape.

For wealth-through-service requests, the established theme is creating useful stories and experiences that help people pursue their own meaningful desires; receiving wealth from that value; and enjoying abundance as time, choice, family security, generosity, comfort, and resources to create more. Gratitude to God is part of this user's stated values when relevant. Do not automatically insert wealth or religion into unrelated scripts.

Use natural spoken language, short paragraphs, and clear phrase boundaries. Give each meaningful action, feeling, or realization room to land before moving on. For character stories, follow [the approved story pacing](../construct-story/SKILL.md#approved-story-pacing): short beats and explicit audio pauses, rather than relying on slower speech to compensate for dense narration. Keep those Inworld-specific settings separate from the single-voice workflow. Avoid dense clauses, stage directions read aloud, exaggerated guarantees, and claims that listening alone cures addiction, guarantees wealth, or controls other people's choices. Reflect beneficial change through the person's actions and support. A specific amount or imagined message can be included when requested as part of the visualization.

## Deliver and hand off

Return the finished transcript in a reusable writing block. When a file is needed, save plain UTF-8 text under `stories/<name>/<version>/story.txt` relative to the generation folder. Source transcripts are version controlled; generated audio is Git-ignored. Choose a new name for a revision unless overwriting that draft was requested.

For roughly six minutes with the approved voice and pauses, the earlier approximately 550-word script is a starting point, not a duration guarantee. Actual length depends on delivery and pauses. Do not stretch the prose with filler to hit a runtime.

Keep the human-readable transcript free of SSML. If voice generation needs a few deliberate breaks, create a separate `_ssml.txt` copy without changing spoken wording. Do not blanket every sentence with break tags: the voice workflow already extends natural gaps.

If audio generation is also requested, use [the voice generation skill](../generate-audio/SKILL.md), retaining this transcript as the exact source. If only a draft or revision was requested, finish with the transcript.
