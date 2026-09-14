---
name: nx-hypnosis-story-gen
description: Construct grounded, inspirational character stories for NX Hypnosis and prepare multi-voice Inworld scripts with approved casting, emotional direction, and pauses. Use for narrative stories such as Roger, rather than short first-person affirmations.
---

## Story purpose

Start with the listener's chosen value and the protagonist's limiting belief. Build an emotionally involving story in which that belief is tested through actions and consequences. Do not explain identity reinforcement inside the spoken narration. Immersion is a presentation choice, not permission for covert influence or fabricated personal memories.

For the Roger example, the limiting belief is that protecting his family means accepting his low station. His growing belief is that he can create abundance by listening, learning, and helping people satisfy meaningful needs. Prayer, family duty, humility, and gratitude are this user's requested values, not mandatory themes for every story.

For the revised Roger brief, faith is the central engine of change: Roger recognizes that his limited knowledge and resources do not define God's limitless abundance. Show him bringing helplessness, fear, gratitude, desires, and uncertainty to God, then acting with renewed openness. Weave remembrance into ordinary work, relationships, irritation, corrections, and enjoyment—not only crises or formal prayer. Do not equate faith with guaranteed business outcomes or portray piety as a performance. See [the revised faith-focused draft](../../stories/roger/v2/story.md). These are this user's Roger-story preferences, not requirements for unrelated stories.

## Narrative construction

- Open with a challenge to the protagonist's place in the world, then quickly reveal why change feels dangerous. Give the listener someone to care about before describing success.
- Build a causal sequence: a need noticed, a fearful choice, an attempt, a specific failure, learning, another attempt, and an earned result. Increase the stakes as the protagonist's competence grows.
- Make the central uncertainty personal: who will the protagonist become under pressure? Let setbacks test the old belief rather than merely delay the next reward.
- Use concrete details to establish stakes, explain a solution, show impact, or reveal character. Avoid decorative routines that distract from the central identity.
- Earn breakthroughs through observation, iteration, help, and honest communication. Coincidence can expose an insight, but follow it with verification and work. Show practical limits: materials, time, skills, deposits, cash flow, obligations, and advice.
- Vary the dramatic shape. Compress repetitive wins; expand meaningful failures and choices. Success should introduce a new problem, not end every scene with an effortless reward.
- Introduce important relationships before the ending. Reveal shared values through small choices and dialogue. Give other characters agency rather than treating them only as praise or rewards.
- Show abundance as both material prosperity and room to rest, serve, choose, protect family, and give. Let later success test the protagonist's integrity.
- End by resolving an early emotional image or fear. A mother's peaceful rest can carry more meaning than a summary of net worth.

These are character-first craft principles, not a guarantee of psychological effects. Keep practical health or financial details plausible; do not present a fictional cure, profit, or testimonial as a verified outcome.

## Preserve and prepare

Use [Roger's source](../../stories/roger/v1/story.md) as a reference for the approved style, not a plot that every story must copy. Once wording is approved, save the human-readable source under `generation/stories/<name>/<version>/story.md`. Preserve the exact word order when converting to audio turns; revisions require a new source version or a requested edit.

Read [the JSON format](../../stories/README.md). Save the parseable script next to its source as `script.json`. Use [Roger's script](../../stories/roger/v1/script.json) as a working example.

- The `cast` maps characters to real Inworld voice IDs. For Roger, retain Edward as Roger, Harold as narrator, Beatrice as Mother, Deborah as Rita, Evan as Tim, Arthur as Rick, Lauren as Katie, Warren as Katie's father, Conrad as manager, and Vinny as coworker. These are this story's approved cast, not universal casting defaults.
- Use ordered `turns` with unique IDs and scene numbers. Only `text` is spoken. Keep “he said” and similar narrative tags with the narrator. Written notes may be read by the narrator; do not announce audition labels in the finished story.
- Put non-spoken delivery guidance in `speaker_instructions` and use per-turn `instruction` for specific emotional changes. Avoid making every line sound equally solemn. Roger's approved audition used expressive, natural heroism, moving from vulnerability toward conviction, rather than Jake's rejected monotone.
- Approved Roger settings: `inworld-tts-2`, `speaking_rate: 0.95`, `delivery_mode: BALANCED`. Store pause lengths explicitly, with short gaps for dialogue tags and longer scene transitions. Native model pauses remain in the audio too.
- Keep each turn below 2,000 characters. Break long narration at paragraph boundaries. Strip Markdown and dialogue quotation marks without dropping or duplicating words.

## Validate, audition, render

From `generation`, validate without credentials or spending:

```sh
python3 scripts/audio/inworld_dialogue.py stories/<name>/<version>/script.json --validate-only
```

Compare spoken words in order to the approved source and inspect speaker assignments. For a new cast, create a short labeled audition when requested; for an approved cast, preserve those choices. Estimate duration from actual sample pacing, with uncertainty, rather than promising an exact runtime.

When generation is authorized:

```sh
python3 scripts/audio/inworld_dialogue.py stories/<name>/<version>/script.json --name <name>-v1 --output-group <name>/<version>
```

The generator reads `INWORLD_API_KEY` from the environment or ignored `generation/.env`. It saves original segments and request metadata, adds the specified pauses and 5ms edge ramps, and outputs WAV and MP3 in ignored `outputs/`. It applies no EQ, reverb, loudness processing, or time stretching. Matching cached requests are reused. A changed request requires a new output name. Reuse verified preview segments only if their exact requests match the full script. Do not retry uncertain API failures blindly.

Verify complete decoding, actual duration, and all expected segments. Saved request metadata establishes what was generated; decoding alone does not prove listening quality. For a requested database tape, continue with [the upload skill](../publish-tape/SKILL.md). Generation alone does not authorize publication; explicit creation/upload does.
