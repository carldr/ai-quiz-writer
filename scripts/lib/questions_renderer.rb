# frozen_string_literal: true

require_relative "sheet_renderer"

# The questions alone, with no answers: the answer sheet with its answers taken
# out, for a copy that can be handed over without giving the answers away.
module QuestionsRenderer
  extend SheetRenderer

  def self.render(quiz)
    body = +sheet_header("Pub Quiz — #{esc(quiz.date)}", "")
    body << paged_rounds(quiz.rounds) do |r|
      case r.format
      when "picture" then picture_grid(r) { |q| picture_cell(q.number, image: q.image) }
      when "multiple-choice" then choices(r)
      else plain(r)
      end
    end
    page("Pub Quiz — #{quiz.date} — Questions", "questions", body)
  end

  # The question, then its lettered options, none of them marked.
  def self.choices(round)
    items = round.questions.map do |q|
      opts = (q.options || []).each_with_index.map do |opt, i|
        "<span>#{(i + "a".ord).chr})&nbsp; #{esc(opt)}</span>"
      end
      body = +esc(q.text)
      body << "<div class=\"options\">#{opts.join}</div>" unless opts.empty?
      "<li>#{body}</li>"
    end
    "<ol class=\"question-list\">#{items.join}</ol>"
  end

  def self.plain(round)
    items = round.questions.map { |q| "<li>#{esc(q.text)}</li>" }
    "<ol class=\"question-list\">#{items.join}</ol>"
  end
end
