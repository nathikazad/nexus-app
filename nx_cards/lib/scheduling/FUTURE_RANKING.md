# Future language-card ranking

Only the language browser's Future tab sorts by priority and displays a score.
Compute over the entire loaded language collection before filtering categories,
collections, or activation. Nothing is written to card data or recall history.

Score = 100 × U × (0.6 + 0.4 × F).

For each card, count distinct Phrase cards containing it directly or through
nested Contains links. Multiple paths count once per phrase; cycles terminate.
Normalize frequency as log(1 + count) / log(1 + maximum count) within a language.
Word/Script U is its own normalized frequency. Phrase U is the average normalized
frequency of its direct components. A collection without phrases has zero scores;
no alternative ranking heuristic is silently substituted.

F is mean direct-component knowledge in the selected language direction:
Future=0, Upcoming=0.1, Current=0.1+0.9×(successful answers/window/0.8), Past=1.
A card without components has neutral F=0.5. The user preference determines the
recall window. Missing components contribute zero rather than presumed mastery.
No unlock bonus or additional unfamiliar-component penalty is applied.

Sort by the full score descending, then stable card ID ascending. Display one
decimal without a percent sign; this is priority, not recall probability.

The implementation was verified against all 330 results in the local Chinese V2
experiment (2026-09-23). The private snapshot is not committed to the repository.
