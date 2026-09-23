---
name: vet-suggestions
description: Research the question and round ideas in SUGGESTIONS.md, reject the poor ones, and move the good ones into CORPUS.md with notes. Use when the user asks to vet or check their suggestions.
---

# Vet suggestions

Claude follows this file when it vets SUGGESTIONS.md with the user.
SUGGESTIONS.md holds the user's notes for questions and rounds, often in
shorthand. Each suggestion ends in one of three places: CORPUS.md, where
`/new-quiz` draws on it; deleted; or left in SUGGESTIONS.md for a later run.
The user decides every one.

## Standard

The Difficulty section of `.claude/skills/new-quiz/SKILL.md` sets the target
every judgement below is made against.

A question is good when:

- web search confirms its answer, and no other answer fits the question as
  worded;
- an average team has between about 10% and 95% chance of answering it. A
  question every team gets, or one almost no team gets, earns nothing;
- it is not a repeat of a question in OLD-QUIZZES.md, quizzes/*/quiz.md or
  CORPUS.md, by the rule in step 7 of `new-quiz`'s Per round section.

A trick question, as `new-quiz` defines it, is worth keeping; say so in its
notes.

A round idea is viable when a full round can be drafted from it, 10 questions
or 15 for a picture round, in which every question meets the standard and the
chances follow the curve to an average of 70%. A picture round also needs an
image to exist for every item; check that candidates exist, and fetch nothing.

## Steps

1. Read SUGGESTIONS.md, CORPUS.md, and the Difficulty section of
   `.claude/skills/new-quiz/SKILL.md`.
2. List every suggestion with a one-line reading of the question or round you
   take it to mean. Where you cannot tell what the user meant — a bare name, a
   link, a phrase that fits several rounds — ask. Put every question to the
   user in one message, and research nothing until the user has confirmed or
   corrected the whole list.
3. Research in parallel sub-agents: one per round idea, and one per batch of
   about five questions. Give each sub-agent the Standard section, the
   Difficulty section, and the confirmed readings of its suggestions. Each
   sub-agent returns, for every suggestion it was given:
   - for a question: the question as it would be asked, the answer, the source
     that confirms it, the estimated chance an average team answers it, the
     result of the dedupe, and a verdict of keep or reject with its reason;
   - for a round: the drafted round, with each answer's source and each
     question's estimated chance; the round's expected average; any occasion
     it suits, such as Halloween; and a verdict of viable or not with its
     reason.
4. Show the user a verdict for every suggestion, with its reason in one line.
   For a kept question, show it as worded with its answer; for a viable round,
   its expected average and three sample questions. The user confirms,
   overrides, or asks for rework; a reworked suggestion goes back through
   step 3.
5. Write each kept suggestion into CORPUS.md: a round under the heading for its
   round type, a question under Questions. A round carries its title, a line saying it was vetted from
   SUGGESTIONS.md on today's date, why it is a good round, any occasion it
   suits, its expected average, the questions in quiz file format
   (docs/quiz-format.md), and a "Before reuse:" note of known faults. A
   question carries the vetting date, its estimated chance, why it is a good
   question, and any known faults.
6. Delete from SUGGESTIONS.md every suggestion the user decided on, kept or
   rejected. Leave the rest for a later run.
