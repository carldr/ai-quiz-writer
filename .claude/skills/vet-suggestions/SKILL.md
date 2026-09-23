---
name: vet-suggestions
description: Research the question and round ideas in SUGGESTIONS.md, reject the poor ones, and move the good ones into CORPUS.md with notes. Use when the user asks to vet or check their suggestions.
---

# Vet suggestions

Claude follows this file when it vets SUGGESTIONS.md with the user.
SUGGESTIONS.md holds the user's notes for questions and rounds, often in
shorthand. Each suggestion ends in one of three places: CORPUS.md, where
`/new-quiz` draws on it; deleted; or left in SUGGESTIONS.md for a later run.
A clear question that passes research goes to CORPUS.md without asking; the
user decides every other suggestion.

## Standard

The Difficulty section of `.claude/skills/new-quiz/SKILL.md` sets the target
every judgement below is made against.

A question is good when:

- web search confirms its answer, and no other answer fits the question as
  worded. Every answer is verified by search, including the ones the note
  already gives and the ones that seem obvious;
- an average team has between about 10% and 95% chance of answering it. A
  question every team gets, or one almost no team gets, earns nothing;
- it is not a repeat of a question in OLD-QUIZZES.md, quizzes/*/quiz.md or
  CORPUS.md, by the rule in step 7 of `new-quiz`'s Per round section.

A trick question, as `new-quiz` defines it, is worth keeping; say so in its
notes.

A round idea is viable when a full round can be drafted from it, 10 questions
or 15 for a picture round, in which every question meets the standard and the
chances follow the curve to an average of 70%. Most themes are viable with the
right questions; a theme fails when it is too obscure or too niche for enough
gettable questions to exist. A picture round also needs an image to exist for
every item; check that candidates exist, and fetch nothing.

## Steps

1. Read SUGGESTIONS.md, CORPUS.md, and the Difficulty section of
   `.claude/skills/new-quiz/SKILL.md`.
2. Sort every suggestion into one of three groups:
   - a clear question: one reading fits the note, and the question can be
     worded from it;
   - an unclear question: a bare name, a link, or a phrase that fits several
     questions, where you cannot tell what the user meant;
   - a round idea.
3. Research the clear questions and every round idea in parallel sub-agents:
   one per round idea, and one per batch of about five questions. Give each
   sub-agent the Standard section, the Difficulty section, and its
   suggestions. Each sub-agent returns, for every suggestion it was given:
   - for a question: the fact and its answer, the source that confirms it, a
     baseline wording with the chance an average team answers it, the
     wordings or formats that make it easier or harder, the result of the
     dedupe, and a verdict of keep or reject with its reason. Where the
     note's wording or answer is wrong, the sub-agent says what it changed;
   - for a round: the drafted round, with each answer's source and each
     question's estimated chance; the round's expected average; any occasion
     it suits, such as Halloween; and a verdict of viable or not with its
     reason.
4. Wait until every sub-agent has returned, re-running any that failed. Then
   write every kept clear question into CORPUS.md, delete it from
   SUGGESTIONS.md, and commit. Show the user one line per question promoted:
   the question as worded, its answer, and any change from the note.
   Steps 5 to 7 start only once this step is done and no work is in flight,
   so each of their messages carries one decision and nothing else.
5. Take the rejected questions one at a time, one per message: the question,
   the answer, and why it fails the standard. The user confirms the rejection,
   and it is deleted from SUGGESTIONS.md, or overrides it, and it is written
   into CORPUS.md.
6. Take the unclear questions one at a time, one per message, and ask what the
   user meant. Once the reading is settled, research it as in step 3; a keep
   is written into CORPUS.md, and a reject is put to the user as in step 5.
7. Take the round ideas one at a time, one per message: the verdict and its
   reason, the expected average, and three sample questions with their
   answers. The user confirms, overrides, or asks for rework; a reworked round
   is researched again as in step 3 and shown again.
8. A suggestion the user defers stays in SUGGESTIONS.md for a later run. Every
   other suggestion is deleted from it once decided.

## Corpus entries

A round goes under the heading for its round type, and carries its title, a
line saying it was vetted from SUGGESTIONS.md on today's date, why it is a
good round, any occasion it suits, its expected average, the questions in quiz
file format (docs/quiz-format.md), and a "Before reuse:" note of known faults.

A question goes under Questions, under a heading that names it. It opens with
the fact in one sentence, ending in the bold answer, then a list:

- Asked as: the baseline wording and its chance;
- Easier and Harder: other wordings or formats, with their chances where
  known;
- Accuracy: wording that must stay for the question to be true;
- Marking: answers to accept or refuse;
- Faults: known weaknesses;
- Why: why it is a good question;
- Vetted: today's date.

Asked as, Why and Vetted are always there; the rest only where there is
something to say.
