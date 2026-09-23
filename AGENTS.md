# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- Render a quiz: `ruby scripts/render.rb quizzes/YYYY-MM-DD`. It writes HTML and PDF sheets to `quizzes/YYYY-MM-DD/out/`, then copies the PDFs to `~/Library/Mobile Documents/com~apple~CloudDocs/Quiz/YYYY-MM-DD/`. It needs Google Chrome at `/Applications/Google Chrome.app` and an iCloud Drive; either missing is an error.
- Run the tests: `ruby test/render_test.rb`
- Run one test: `ruby test/render_test.rb -n test_name`

Everything runs on stock Ruby with no gems; Minitest ships with it.

## How a quiz is made

The `/new-quiz` skill, `.claude/skills/new-quiz/SKILL.md`, drives a quiz from theme proposals to rendered sheets, one round at a time with the user approving each. It reads three data files at the repo root:

- `OLD-QUIZZES.md`: every past question, in quiz file format. New questions are deduped against it and against `quizzes/*/quiz.md`. It is compiled from the raw originals in `old-quiz-texts/`.
- `ROUND-HISTORY.md`: one row per past round, newest first, so themes are not reused too soon.
- `CORPUS.md`: vetted suggestions, ready to use, with notes on why each is worth asking.

The user notes ideas for questions and rounds in `SUGGESTIONS.md`. The `/vet-suggestions` skill, `.claude/skills/vet-suggestions/SKILL.md`, researches each one with the user, moves the good ones into `CORPUS.md`, and deletes every one decided on from `SUGGESTIONS.md`.

`docs/quiz-format.md` specifies `quiz.md`. The parser is strict: a line that is not a recognised construct is an error, never skipped.

## Renderer

`scripts/render.rb` is the entry point; the work is in `scripts/lib/`. `QuizParser` turns `quiz.md` into `Quiz`, `Round` and `Question` structs. Three renderers turn a `Quiz` into HTML, and `Cli` writes the files, prints each to PDF with headless Chrome, and copies the PDFs to iCloud.

The three sheets are different documents, not one printed three ways:

- The answer sheet has every question with its answer bold, a round per page.
- The team sheet carries no question text, a round per page. Picture rounds get numbered boxes, multiple choice a table of bare options, and other rounds ruled lines.
- The picture sheet has the image grid only.

The renderers share `SheetRenderer` through `extend`. It holds the HTML document, `round_header`, `paged_rounds`, and `picture_grid`/`picture_cell`. The picture round uses the same grid and cell geometry on all three sheets, so each team box sits where its picture is.

A multiple-choice answer repeats the correct option and may add a bracketed aside, such as the dates behind a "which came first". The answer sheet prints the aside as a note under the options. The team sheet never shows it.

## Stylesheets

`scripts/render/common.css` is inlined first, then the sheet's own `answers.css`, `team.css` or `pictures.css`. A rule used by more than one sheet goes in `common.css`, and a rule used by one sheet goes in that sheet's file. Style by class, never by element, and write class names in full rather than abbreviated.

## Prose judge

`.prose-ignore` keeps the prose judge off `quizzes/`, `CORPUS.md` and `SUGGESTIONS.md`, which hold quiz questions rather than prose.
