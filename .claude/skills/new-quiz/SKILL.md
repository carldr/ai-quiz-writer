---
name: new-quiz
description: Generate a new pub quiz round by round, with web-verified answers, no repeats from past quizzes, and rendered printable sheets. Use when Carl asks to create/generate a quiz. Takes the quiz date as argument.
---

# New quiz

Generate a pub quiz for the date given as argument (ask if missing). Work
round by round; never move to the next round without approval.

## Structure

Default: Round 1 picture (15 questions, / 15), one or two multiple-choice
rounds (/ 10 each), one or two novelty rounds (/ 10 each), final round
general knowledge (20 questions, / 20). Total 75. Ask up front if Carl wants
a different shape or a theme (seasonal, event-based). NEVER propose music or
audio rounds.

Study `OLD-QUIZZES.md` for tone, difficulty, and the kinds of novelty rounds
used before (connections, anagrams, true/false, "X or Y?", single-letter
answers, headlines...). Novelty round formats may be reused; questions may not.

## Per round

1. Propose 2–3 round themes with a one-line description each. Carl picks.
2. Draft the full round in the quiz file format (see docs/quiz-format.md).
3. Verify EVERY answer with web search. Correct or replace any question whose
   answer cannot be confirmed; if kept despite doubt, flag it to Carl.
4. Dedupe: grep OLD-QUIZZES.md and every quizzes/*/quiz.md for each question's
   key fact (search for the answer and for distinctive question words, not the
   whole sentence). Replace any repeat — a question counts as repeated if it
   asks for the same fact, even worded differently.
5. Show the round to Carl. Apply requested swaps (re-verify and re-dedupe
   replacements) until approved.

## Picture round

After the 15 items are approved:
1. Fetch 2–3 candidate images per item into quizzes/YYYY-MM-DD/images/ as
   candidate-NN-a.jpg, candidate-NN-b.jpg, ...
2. Write quizzes/YYYY-MM-DD/images/contact-sheet.html showing all candidates
   with their filenames; tell Carl to open it and pick.
3. Copy each pick to the final name r1-NN.png/jpg matching the quiz file, and
   delete the unused candidates and the contact sheet.
Image rights are Carl's call — prefer official logos/promotional images and
say where each came from.

## Finish

1. Write quizzes/YYYY-MM-DD/quiz.md (format: docs/quiz-format.md).
2. Run: ruby render.rb quizzes/YYYY-MM-DD
3. Fix any parse errors, and report the three PDF paths.
