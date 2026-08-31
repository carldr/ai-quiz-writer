---
name: new-quiz
description: Generate a new pub quiz round by round, with web-verified answers, no repeats from past quizzes, and rendered printable sheets. Use when Carl asks to create/generate a quiz. Takes the quiz date as argument.
---

# New quiz

Generate a pub quiz for the date given as argument (ask if missing). Work
round by round; never move to the next round without approval.

## Structure

Default: Round 1 picture (15 questions, / 15), then four rounds of 10, final round general knowledge (20 questions, / 20). Total 75. Round 2 is always multiple choice, usually themed (past examples: Size Matters, Guess the Year, Fictional Places). Rounds 3–5 mix novelty formats and themed open rounds; occasionally one of them is a second multiple-choice round. Ask up front if Carl wants a different shape or a theme (seasonal, event-based). A theme applies to one round only — the picture round or round 2, Carl's choice — never the whole quiz. NEVER propose music or audio rounds, even though past quizzes had them. Never propose a sports round except during a special event such as an Olympics or a World Cup; the regulars don't enjoy them.

Study `OLD-QUIZZES.md` for tone, difficulty, and the kinds of novelty rounds
used before (connections, anagrams, true/false, "X or Y?", single-letter
answers, headlines...). Novelty round formats may be reused; questions may not.

Questions in every round must work for a mix of ages.

## Per round

1. Read ROUND-HISTORY.md and propose 3–4 round themes with a one-line
   description each, as a checklist — Carl can pick more than one. Do not
   propose a theme used in a recent quiz.
2. Start a sub-agent per picked theme, in parallel, each generating example
   questions for its theme. Give each sub-agent ROUND-HISTORY.md to read for
   tone and to avoid recent overlaps. For a picture round, the examples
   describe what the pictures could be; no images are fetched at this stage.
3. Present the example questions for every picked theme. Carl picks the final
   theme.
4. Start a sub-agent to review the chosen theme's questions, then offer the
   sub-agent's improvements or changes to Carl.
5. Draft the full round in the quiz file format (see docs/quiz-format.md).
6. Verify EVERY answer with web search. Correct or replace any question whose
   answer cannot be confirmed; if kept despite doubt, flag it to Carl.
7. Dedupe: grep OLD-QUIZZES.md and every quizzes/*/quiz.md for each question's
   key fact (search for the answer and for distinctive question words, not the
   whole sentence). Replace any repeat — a question counts as repeated if it
   asks for the same fact, even worded differently.
8. Show the round to Carl. Apply requested swaps (re-verify and re-dedupe
   replacements) until approved.

## Picture round

After the 15 items are approved:
1. Fetch 2–3 candidate images per item into quizzes/YYYY-MM-DD/images/ as
   candidate-NN-a.jpg/png (keep each image's real extension), candidate-NN-b..., ...
2. Write quizzes/YYYY-MM-DD/images/contact-sheet.html showing all candidates
   with their filenames; tell Carl to open it and pick.
3. Rename each pick to the final name r1-NN.png/jpg matching the quiz file, then
   delete the remaining candidates and the contact sheet, so only the r1-NN files remain in images/.
Image rights are Carl's call — prefer official logos/promotional images and
say where each came from.

## Finish

1. Write quizzes/YYYY-MM-DD/quiz.md (format: docs/quiz-format.md).
2. Run: ruby render.rb quizzes/YYYY-MM-DD
3. Fix any parse errors, and report the three PDF paths.
4. Add the new quiz's rounds to the top of the ROUND-HISTORY.md table, which
   runs newest first.
