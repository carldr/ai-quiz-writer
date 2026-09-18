# Pub quiz generator

This repository generates a pub quiz with Claude Code and renders it as printable A4 PDFs.

## What it does

A quiz has six rounds and 75 points by default:

- a picture round of 15 images;
- four rounds of 10;
- a general knowledge round of 20 questions.

Claude writes the quiz round by round. Claude proposes themes, then drafts and verifies the questions. The user picks the themes and approves each round.

Claude checks every answer with web search. Claude also deduplicates the questions against every earlier quiz in the repository.

A render produces three sheets:

- the answer sheet, for the quizmaster;
- the team sheet, which teams write on;
- the picture sheet, which teams look at.

The team sheet prints no question text, because the quizmaster reads the questions out.

## Dependencies

The repository runs on macOS only.

### Homebrew

Homebrew installs curl-impersonate and can install the other dependencies. Install Homebrew from brew.sh.

### Ruby 3.2 or later

The renderer needs Ruby 3.2 or later, with no gems. The Ruby that ships with macOS is 2.6, which is too old. To print the version in use, run:

```
ruby -v
```

Install a current Ruby with a Ruby version manager such as mise.

### Google Chrome

Chrome prints the HTML sheets to PDF, and must be installed at `/Applications/Google Chrome.app`. Install Chrome from google.com/chrome, or with Homebrew:

```
brew install --cask google-chrome
```

### iCloud Drive

A render copies the PDFs to `~/Library/Mobile Documents/com~apple~CloudDocs/Quiz/YYYY-MM-DD/`. The render fails if iCloud Drive is missing.

### Claude Code

Claude Code, with web search, runs the `/new-quiz` skill that writes the quiz. Claude Code needs a Pro, Max, Team, Enterprise or Console account. Install Claude Code with:

```
curl -fsSL https://claude.ai/install.sh | bash
```

The first run of `claude` opens a browser for you to log in.

### curl-impersonate

Claude uses curl-impersonate to fetch picture-round images from sites that block plain curl. Install curl-impersonate with:

```
brew install lexiforest/tap/curl-impersonate
```

## Creating a quiz

The repository comes with the author's past quizzes, in these five places:

- `OLD-QUIZZES.md`
- `old-quiz-texts/`
- `quizzes/`
- `ROUND-HISTORY.md`
- `FUTURE-QUIZ-ROUNDS.md`

To use your own past quizzes instead, empty all five. Then write your past quizzes into `OLD-QUIZZES.md` in the `quiz.md` format, one quiz after another.

If you have no past quizzes of your own, keep the author's quizzes. New quizzes will not repeat any question in the author's quizzes.

To create a quiz:

1. Start Claude Code in the repository directory:

   ```
   claude
   ```

2. At the Claude Code prompt, type the command below, with the date the quiz will be played:

   ```
   /new-quiz YYYY-MM-DD
   ```

3. Claude asks whether to use the default round structure, then offers themes drawn from the date and season.
4. For each round, Claude offers 3–4 themes and drafts example questions for each theme you pick. You choose one.
5. Claude sends the chosen round to a review sub-agent. Once you approve the round, Claude has a fresh sub-agent verify the final text of every question in the round.
6. For the picture round, Claude fetches 2–3 candidate images per item and writes a contact sheet, `quizzes/YYYY-MM-DD/images/contact-sheet.html`. Open the contact sheet in a browser and tell Claude which candidate to use for each item, by filename.
7. When you have approved every round, Claude writes `quizzes/YYYY-MM-DD/quiz.md` and renders it.

The PDFs are then in `quizzes/YYYY-MM-DD/out/` and in `~/Library/Mobile Documents/com~apple~CloudDocs/Quiz/YYYY-MM-DD/`.

## Rendering by hand

`docs/quiz-format.md` specifies the `quiz.md` format.

To render a quiz that already has a `quiz.md`, run:

```
ruby scripts/render.rb quizzes/YYYY-MM-DD
```

The renderer writes the sheets to `quizzes/YYYY-MM-DD/out/` as `answers`, `team` and `pictures`, each as HTML and PDF.

The HTML files stay in `out/`, so you can edit a sheet by hand and print it again. Rendering again overwrites the files in `out/`, including your hand edits. To print an edited sheet, open its HTML file in Chrome and print it.

## Tests

To run the tests:

```
ruby test/render_test.rb
```

To run one test:

```
ruby test/render_test.rb -n test_name
```

## Where things are

- `quizzes/YYYY-MM-DD/`: one directory per quiz, holding `quiz.md`, `images/` and `out/`.
- `OLD-QUIZZES.md`: every question from quizzes written before this repository, used for deduplication. The originals are in `old-quiz-texts/`.
- `ROUND-HISTORY.md`: one row per past round, newest first.
- `FUTURE-QUIZ-ROUNDS.md`: rounds drafted for an earlier quiz and not used, kept for reuse.
- `scripts/`: the renderer. Its stylesheets are in `scripts/render/`.

The skill reads `OLD-QUIZZES.md`, `ROUND-HISTORY.md` and `FUTURE-QUIZ-ROUNDS.md`. When a quiz is finished, the skill adds the quiz's rounds to `ROUND-HISTORY.md`, and the rounds it didn't use to `FUTURE-QUIZ-ROUNDS.md`.

The skill never updates `OLD-QUIZZES.md`. The skill also checks new quizzes for repeats against `quizzes/*/quiz.md`.

## Licence

MIT.
