# AI-aided pub quiz generator — design

2026-08-31. Approved in conversation; this document records the design.

## Overview

Carl runs a roughly monthly pub quiz, historically built by hand in Apple Pages,
at two different pubs. This repo replaces that with a Claude Code workflow: a
`/new-quiz` project skill generates a quiz round by round with Carl approving
each round, a Ruby renderer turns the quiz file into three printable PDFs, and
the accumulated history guarantees no question or round is ever repeated — at
either pub.

Components:

- `quizzes/YYYY-MM-DD.md` — one markdown file per quiz (the source of truth).
- `quizzes/YYYY-MM-DD-images/` — picture-round images for that quiz.
- `render.rb` — stdlib-only Ruby script; quiz file in, three HTML + three PDF out.
- `.claude/skills/new-quiz/` — the generation skill.
- `OLD-QUIZZES.md` — the 11 transcribed past quizzes (2024-05-19 to 2026-08-04),
  kept as-is as historical record.
- `docs/quiz-format.md` — the quiz file format documentation (written via the
  documentation process, since it is user-facing).

## Quiz structure

Default shape (overridable per quiz): a 15-item picture round in a 3×5 grid,
one or two multiple-choice rounds, a couple of novelty rounds, and a 20-question
general knowledge round; 75 points total. No music or audio rounds are ever
proposed.

## Quiz file format

Markdown, not YAML — long questions wrap badly in YAML. The format is the
existing OLD-QUIZZES.md layout plus per-round `Format:` and `Instructions:`
lines and per-question image paths in picture rounds:

```markdown
# Pub Quiz — 2026-09-07

Total: / 75

## Round 1: Brands (/ 15)

Format: picture
Instructions: Identify the brand from a cropped logo.

1. **Dunlop** — images/r1-01.png

## Round 2: Size Matters (/ 10)

Format: multiple-choice
Instructions: Circle your answers.

1. Which is the largest wine bottle size? a) Magnum b) Midas (30 litres) c) Nebuchadnezzar — **b) Midas (30 litres)**

## Round 5: General Knowledge (/ 20)

Format: open

1. In which city is Europe's oldest university? — **Bologna**
```

Rules:

- Header: `# Pub Quiz — YYYY-MM-DD`, then `Total: / N`.
- Round heading: `## Round N: Name (/ points)`.
- `Format:` is one of `picture`, `multiple-choice`, `open`, `true-false`; it
  drives sheet layout.
- `Instructions:` is printed on the team sheet. Optional.
- The answer is always the bold segment after the em dash; team sheets are
  produced by stripping it.
- Picture-round image references are written `images/r{round}-{question}.png`;
  the renderer resolves the `images/` prefix to the quiz's
  `quizzes/YYYY-MM-DD-images/` directory.

## Renderer

`ruby render.rb quizzes/YYYY-MM-DD.md` writes to `quizzes/YYYY-MM-DD-out/`:

- `answers.html` / `answers.pdf` — quizmaster sheet: everything, answers bold,
  per-round score boxes.
- `team.html` / `team.pdf` — what teams write on: multiple-choice options to
  circle, numbered write-in lines for open and true-false rounds, no answers.
- `pictures.html` / `pictures.pdf` — the separate picture sheet: 3×5 image
  grid, numbered, no labels, one page.

PDFs come from the HTML via headless Chrome
(`chrome --headless --print-to-pdf`), A4. Layout lives once in CSS templates
inside the script, so output is identical month to month. The HTML files stay
in the output directory so a one-off manual tweak can be re-printed.

Parsing is strict: an unknown `Format:` value, a question without a bold
answer, or a referenced image file that does not exist is a hard error naming
the offending line numbers. Better to fail at render time than at the pub.

## Generation workflow (`/new-quiz` skill)

Run as `/new-quiz <date>`. Round by round:

1. Propose 2–3 round themes; Carl picks one.
2. Draft the full round.
3. Web-verify every answer; flag any that cannot be confirmed.
4. Check every question against history (OLD-QUIZZES.md plus every file in
   `quizzes/`); replace repeats before presenting.
5. Carl approves the round or requests swaps; only then move to the next round.

Picture round: after the 15 items are approved, fetch 2–3 candidate images per
item into `quizzes/YYYY-MM-DD-images/` and build an HTML contact sheet for Carl
to pick from; each pick is renamed to the `r{round}-{question}` path the quiz
file references. Image rights clearance is manual — candidates vary in quality
and rights.

When all rounds are approved: write the quiz file, run the renderer, report the
paths of the three PDFs.

## History and dedupe

- `OLD-QUIZZES.md` is frozen history; new quizzes live only in `quizzes/`.
- Dedupe reads both, so the skill always sees every past question and round.
- Repetition is banned outright — there is no per-pub tracking.

## Error handling

- Renderer: strict parse errors with line numbers, as above; a missing Chrome
  binary is reported with the expected path.
- Skill: an answer that fails web verification is never silently kept — it is
  flagged to Carl with what was found.

## Testing

- Parser and sheet generation: unit tests against a small fixture quiz file,
  including the error cases (bad `Format:`, missing answer, missing image).
- PDF step: exercised manually (it is a Chrome invocation, not logic).
- Built TDD-first per the normal workflow.

## Out of scope

- No standalone CLI or web app.
- No music or audio rounds.
- No Pages document generation.
- No automatic image rights clearance.
