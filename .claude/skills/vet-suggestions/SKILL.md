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

Vetting produces candidates, not finished rounds. A round idea yields a
candidate round and a set of candidate questions. Each question stands on its
own: it can be used in any round and any format, true/false or multiple choice
included, even when its round is rejected. Wording and difficulty are fitted
when a quiz is written.

The Difficulty section of `.claude/skills/new-quiz/SKILL.md` sets the target
a round idea is judged against, and how every question is worded.

A question is good when:

- web search confirms its answer, and no other answer fits the question as
  worded. Every answer is verified by search, including the ones the note
  already gives and the ones that seem obvious;
- it is not a repeat of a question in OLD-QUIZZES.md, quizzes/*/quiz.md or
  CORPUS.md, by the rule in step 7 of `new-quiz`'s Per round section.

If the note's answer is wrong, look for the right answer. If the question
only holds with a qualifier, a definition, or an argument ready for a
challenge, drop it. If in doubt, drop it; there are always more questions.

How hard a question is depends on its wording, which is fitted to a round's
curve when the round is written, so a question's difficulty is left to then.
A trick question, as `new-quiz` defines it, is worth keeping; say so in its
notes.

A round idea is viable when an average team could score 70% on the theme:
enough of its facts are widely known, or can be worked out by a team that
doesn't know them. A clue that gives the answer away without drawing on the
theme, such as naming Beyoncé to identify Destiny's Child, does not make the
theme gettable. The sub-agent that drafts the round does not judge its
difficulty. A separate reviewer is given the drafted questions and the
Difficulty section, with no target to fit. It rates each question's chance,
and says whether the theme can reach 70%. A picture round also needs an image
to exist for every item; check that candidates exist, and fetch nothing.

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
   - for a question: the fact and its answer, the source that confirms it,
     an explanation of the answer that would settle a team's challenge, a
     short, plain baseline wording, the clues or formats that make it
     easier or harder, the result of the
     dedupe, and a verdict of keep or reject with its reason. Where the
     note's wording or answer is wrong, the sub-agent says what it changed;
   - for a round: the candidate questions, 10 or 15 for a picture round, each
     with its answer, the source that confirms it, and the result of the
     dedupe; any occasion the round suits, such as Halloween; and the formats
     each question would suit besides the round's own.
4. For each round, start a reviewer sub-agent, as the Standard section
   describes. Give it the candidate questions and the Difficulty section, and
   nothing that suggests what the chances should be. It returns each
   question's chance as worded, the round's expected average, and a verdict
   of viable or not with its reason.
5. Wait until every sub-agent has returned, re-running any that failed. Then
   write every kept clear question into CORPUS.md, delete it from
   SUGGESTIONS.md, and commit. Show the user one line per question promoted:
   the question as worded, its answer, and any change from the note.
   Steps 6 to 8 start only once this step is done and no work is in flight,
   so each of their messages carries one decision and nothing else.
6. Take the rejected questions one at a time, one per message: the question,
   the answer, and why it fails the standard. The user confirms the rejection,
   and it is deleted from SUGGESTIONS.md, or overrides it, and it is written
   into CORPUS.md.
7. Take the unclear questions one at a time, one per message, and ask what the
   user meant. Once the reading is settled, research it as in step 3; a keep
   is written into CORPUS.md, and a reject is put to the user as in step 6.
8. Take the round ideas one at a time, one per message: the reviewer's verdict
   and its reason, its expected average, and three sample questions with their
   answers. The user confirms, overrides, or asks for rework; a reworked round
   is researched and reviewed again as in steps 3 and 4, and shown again.
   When a round is rejected, offer its questions that meet the standard for
   the Questions section of CORPUS.md, each noting the formats it suits. For
   example, "Simon & Garfunkel first recorded as Tom and Jerry" suits true or
   false, or multiple choice against two other cartoon duos.
9. A suggestion the user defers stays in SUGGESTIONS.md for a later run. Every
   other suggestion is deleted from it once decided.

## Corpus entries

A round goes under the heading for its round type, and carries its title, a
line saying it was vetted from SUGGESTIONS.md on today's date, why it is a
good round, any occasion it suits, the reviewer's verdict and expected
average, the sample questions in quiz file format (docs/quiz-format.md), and
a "Before reuse:" note of known faults. The sample questions are candidates,
not fitted to the curve.

A question goes under Questions, under a heading that names it. It opens with
the fact in one sentence, ending in the bold answer, then a list:

- Asked as: the baseline wording;
- Explained: the answer in plain words, complete enough for the quizmaster to
  read out or to settle a team's challenge with;
- Easier and Harder: clues to add or remove, or a change of format;
- Accuracy: wording that must stay for the question to be true;
- Marking: answers to accept or refuse;
- Faults: known weaknesses;
- Why: why it is a good question;
- Vetted: today's date.

Asked as, Explained, Why and Vetted are always there; the rest only where there is
something to say.
