# frozen_string_literal: true

require_relative "sheet_renderer"

# The quizmaster's copy: every question with its answer in bold.
#
# Rounds run on down the page rather than starting a new one, so the quizmaster
# turns as few pages as possible while reading. Answers carry whatever
# explanation the quiz file gave them, because that is the part read out after
# the sheets are collected.
module AnswersRenderer
  extend SheetRenderer

  def self.render(quiz)
    body = +sheet_header("Pub Quiz — #{esc(quiz.date)}", "____ / #{quiz.total}")
    body << paged_rounds(quiz.rounds) do |r|
      case r.format
      when "picture" then pictures(r)
      when "multiple-choice" then choices(r)
      else plain(r)
      end
    end
    page("Pub Quiz — #{quiz.date} — Answers", "answers", body)
  end

  # The picture sheet's grid with the answer captioned over each image, so this
  # can be laid beside a team sheet and marked against what the teams saw.
  def self.pictures(round)
    picture_grid(round) { |q| picture_cell(q.number, answer: esc(q.answer), image: q.image) }
  end

  # The question, then its options indented below with the correct one bold.
  def self.choices(round)
    items = round.questions.map do |q|
      correct = answer_index(q)
      opts = (q.options || []).each_with_index.map do |opt, i|
        text = esc(opt)
        text = "<strong>#{text}</strong>" if i == correct
        "<span>#{(i + "a".ord).chr})&nbsp; #{text}</span>"
      end
      body = +esc(q.text)
      body << "<div class=\"options\">#{opts.join}</div>" unless opts.empty?
      "<li>#{body}</li>"
    end
    "<ol class=\"question-list\">#{items.join}</ol>"
  end

  # Question then answer on one line, for open and true-false rounds.
  def self.plain(round)
    items = round.questions.map do |q|
      "<li>#{esc(q.text)} <strong>#{esc(q.answer)}</strong></li>"
    end
    "<ol class=\"question-list\">#{items.join}</ol>"
  end

  # Which option is correct, as an index, taken from the letter the answer starts
  # with: "b) Flake" is index 1. Returns nil when the answer carries no letter,
  # in which case no option is emboldened.
  def self.answer_index(question)
    m = /\A([a-d])\)/.match(question.answer.to_s)
    m ? m[1].ord - "a".ord : nil
  end
end
