# Article text extraction

`Readability.js` is Mozilla Readability 0.6.0, vendored unchanged from
https://github.com/mozilla/readability/tree/0.6.0 under the Apache 2.0 license
in LICENSE.md. It runs locally against a clone of the loaded web page.

`extract.js` retains article text and paragraph boundaries while dropping HTML,
link destinations, scripts and surrounding navigation. It does not crawl links.
The browser supplies this text as reference context for the source document's
conversation, never as a separate document or transcript.
