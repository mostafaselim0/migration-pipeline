# The optional LLM step

Nothing in the pipeline needs a language model.  The model is a helper for one job only: drafting the reviewed rules
of screens whose legacy logic the knowledge base has never seen (NEW) or that the client changed (CHANGED logic).  The
delta stage lists them in `work/llm/worklist.json`; for a client close to the product the list is short or empty

## Why it stays cheap

* **Only the worklist.**  SAME screens reuse reviewed rules; nothing is sent for them.
* **One screen per call, no conversation.**  Each prompt holds the generated screen (tables and columns, one line per
  block), the product's rules when the screen is CHANGED, and only the business-logic triggers of the legacy form
  (validation, transaction, derivation, action, defaulting); navigation, key and cosmetic triggers are left out,
  comments and blank lines stripped, the whole cut at `--chars` (20,000 by default).  A typical screen is 8-10k tokens.
* **Only the transpiler's residue.**  A screen with Forms source first goes through the deterministic transpile step
  (stage generate): plain validations, numbering, defaults, lookups and procedure buttons are already rules.  The prompt
  carries only `work/transpiled/<FORM>.residue.json`, the triggers that rewrite could not express, which is usually a
  fraction of the form's code.
* **The brief is cached.**  The instructions (`knowledge/<product>/contracts/LLM_BRIEF.md`, about 1k tokens) are the
  same for every screen and sent with prompt caching.
* **A hard budget.**  `--budget` stops before a call would exceed it; `--max` limits the number of screens.
* **Declarative answers.**  The model returns the override JSON the generator already understands (lists, defaults,
  read-only, computed columns, validations, keys), not application code.

## Three ways to run it

```
python pipeline.py <c> llm --prepare [FORM ...]      # writes work/llm/prompts/<FORM>.md, no model call
python pipeline.py <c> llm --import                  # checks answers saved as work/llm/answers/<FORM>.json
python pipeline.py <c> llm --budget 300000 [--max 20] [--model claude-sonnet-5] [FORM ...]
```
* `--prepare` + `--import` need no API key: paste `_BRIEF.md` and a prompt into Claude (claude.ai or Claude Code), save
  the JSON answer, import it.
* The direct mode needs `pip install anthropic` and the environment variable `ANTHROPIC_API_KEY`.

**Data protection.**  Prompts contain the client's legacy code and table structure (no table data).  Sending them to
a model provider is a transfer to an external service: do it only with the client's agreement.

## Every answer is checked before it is used

Against the client's own database: columns must exist, list-of-values and computed SQL must parse, validation and
after-save PL/SQL must compile, trigger rules are compiled into a disabled test trigger and dropped again.  Whatever
fails is removed and turned into a question.  The draft is written to `clients/<c>/overlay/overrides/<FORM>.json` with
`"_review": "llm draft ..."`, the model's `"_questions"` and `"_confidence"`.

## Review

A draft is used by the next `generate` / `build`, so review it first: read the rules against the legacy triggers in
the prompt, answer the questions with a key user, remove `_review` when accepted.  If the rule is product behaviour
(other clients will have it too): `python pipeline.py <c> promote <FORM>`.
