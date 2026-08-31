# Quiz format

## File layout

- Each quiz lives at `quizzes/YYYY-MM-DD/quiz.md`.
- The quiz's images live in `quizzes/YYYY-MM-DD/images/`, named `r{round}-{question}.png`.
- Rendered sheets go to `quizzes/YYYY-MM-DD/out/`.

`scripts/render.rb` needs only stock Ruby, and expects Google Chrome at `/Applications/Google Chrome.app`. The stylesheets are in `scripts/render/`. `common.css` holds what all three sheets use and is inlined first; `answers.css`, `team.css` and `pictures.css` follow, each holding only what its own sheet needs.

## Header

The file starts with `# Pub Quiz — YYYY-MM-DD`, then `Total: / N`. The dash in the header line is an em dash (U+2014).

## Rounds

A round heading is `## Round N: Name (/ points)`.

Each round has a `Format:` line, one of `picture`, `multiple-choice`, `open`, `true-false`. The `Format:` line drives sheet layout. `Format:` must appear before the round's first question; a question before it is a parse error.

`Instructions:` is printed on the team sheet. The `Instructions:` line is optional.

The team sheet prints no question text. Teams hear the questions read out, and each round starts a new page. What a round prints depends on its format:

- A `picture` round prints a 3-column grid of numbered empty boxes.
- A `multiple-choice` round prints a table of the options, one row per question, for teams to circle. The `a)` labels are dropped.
- A `true-false` round prints "True / False" beside a numbered ruled line.
- An `open` round prints a numbered ruled line.

## Questions

Question lines are numbered `N. `, and the separator on every question line is an em dash (U+2014). In an `open`, `true-false` or `multiple-choice` round, the answer is the bold segment after the em dash.

Multiple-choice options are written inline in the question text as `a) ... b) ... c) ...`, and the bold answer repeats the correct option. The renderer splits the options off the question text.

```markdown
1. Which is the largest wine bottle size? a) Magnum b) Midas (30 litres) c) Nebuchadnezzar — **b) Midas (30 litres)**
```

Picture-round lines are `1. **Answer** — images/r1-01.png`: the bold answer comes before the em dash and the image path after it. Picture-round image references are written `images/r{round}-{question}.png`, relative to `quiz.md`.

Point values in `Total:` and round headings, and question numbers, are printed as written. The parser does not check that they add up or run in sequence.

Parsing is strict. An unknown `Format:` value, a question without a bold answer, a referenced image file that does not exist, or any non-blank line that is not a header, `Total:`, round heading, `Format:`, `Instructions:` or numbered question line is a hard error naming the offending line numbers.

## Rendering

Run `ruby scripts/render.rb quizzes/YYYY-MM-DD`. The argument is the directory; `quiz.md` is implied. The command writes to `quizzes/YYYY-MM-DD/out/`:

- `answers.html` and `answers.pdf` — the quizmaster sheet: every question with its answer bold, and per-round score boxes. Rounds flow on from one another rather than starting a new page. A picture round prints its images with the answer captioned on each.
- `team.html` and `team.pdf` — what teams write on. The team sheet carries no question text, and each round starts a new page.
- `pictures.html` and `pictures.pdf` — the image grid, numbered, no labels, one page.

`pictures.html` and `pictures.pdf` are only produced when the quiz has a picture round. The picture grid is 3 columns. A 15-image round is the standard shape and fits on one A4 page. Every grid cell is 4:3. An image with a different aspect ratio is scaled to fill the cell and cropped equally at the two overflowing edges.

PDFs come from the HTML via headless Chrome, A4. The three PDFs are then copied to `~/Library/Mobile Documents/com~apple~CloudDocs/Quiz/YYYY-MM-DD/`, taking the date from the quiz's own header. A second render of the same quiz overwrites them. `--no-pdf` skips both the Chrome step and the copy. The HTML files stay in `out/` so a one-off manual tweak can be re-printed.

## Example

```markdown
# Pub Quiz — 2026-08-31

Total: / 8

## Round 1: General Knowledge (/ 2)

Format: open

Instructions: One point per question.

1. Sample question text? — **Sample answer**
2. Second sample question text? — **Second sample answer**

## Round 2: Multiple Choice (/ 2)

Format: multiple-choice

1. Which is the largest wine bottle size? a) Magnum b) Midas (30 litres) c) Nebuchadnezzar — **b) Midas (30 litres)**
2. Sample question text? a) First option b) Second option c) Third option — **a) First option**

## Round 3: True or False (/ 2)

Format: true-false

1. Sample statement. — **True**
2. Second sample statement. — **False**

## Round 4: Pictures (/ 2)

Format: picture

1. **Sample answer** — images/r4-01.png
2. **Second sample answer** — images/r4-02.png
```
