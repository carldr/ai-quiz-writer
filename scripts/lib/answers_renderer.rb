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

  # The question, then its options with the correct one bold, then whatever the
  # answer added to that option, on a line of its own. The team sheet prints
  # neither the answer nor the note.
  def self.choices(round)
    items = round.questions.map do |q|
      correct = answer_index(q)
      option, note = answer_parts(q, (q.options || [])[correct.to_i])
      opts = (q.options || []).each_with_index.map do |opt, i|
        text = i == correct ? "<strong>#{esc(option)}</strong>" : esc(opt)
        "<span>#{(i + "a".ord).chr})&nbsp; #{text}</span>"
      end
      body = +esc(q.text)
      body << "<div class=\"options\">#{opts.join}</div>" unless opts.empty?
      body << "<p class=\"answer-note\">#{esc(note)}</p>" if note
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

  # The answer repeats the correct option and usually adds a bracketed aside.
  # Returns the text to embolden in the options row, and the note for the line
  # below, or nil.
  #
  # Neither returned value carries the option's letter, which is printed beside
  # the option already. A note is a bracketed aside, returned without its
  # brackets. An answer that adds anything else, or that does not begin with its
  # option, is returned whole with no note.
  def self.answer_parts(question, option)
    text = question.answer.to_s.sub(/\A[a-d]\)\s*/, "")
    return [text, nil] if option.nil? || !text.start_with?(option)

    note = text[option.length..].strip
    return [option, nil] if note.empty?
    return [text, nil] unless note.start_with?("(") && note.end_with?(")")

    [option, note[1..-2].strip]
  end
end
