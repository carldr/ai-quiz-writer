# frozen_string_literal: true

require_relative "sheet_renderer"

# What teams write on.
#
# It carries no question text, because the quizmaster reads the questions out and
# a printed question would let a team work ahead. What a round prints is a place
# to write the answer, in the shape that round needs.
#
# Each round starts a new page, so a table can pass one round around while
# holding on to the rest.
module TeamRenderer
  extend SheetRenderer

  # Every round but the last carries the page-break class, so each starts a new
  # page without leaving a blank one at the end.
  def self.render(quiz)
    body = +sheet_header("Team <span class=\"write-in team-name\"></span>",
                         "____ / #{quiz.total}")
    last = quiz.rounds.length - 1
    quiz.rounds.each_with_index do |r, i|
      body << "<section#{i == last ? "" : " class=\"page-break\""}>"
      body << round_header(r)
      body << case r.format
              when "picture" then boxes(r)
              when "multiple-choice" then choices(r)
              when "true-false" then lines(r, true_false: true)
              else lines(r)
              end
      body << "</section>"
    end
    page("Pub Quiz — #{quiz.date} — Team Sheet", "team", body)
  end

  # The picture sheet's grid with an empty box in place of each image, so a box
  # sits where its picture was.
  def self.boxes(round)
    picture_grid(round) { |q| "<div class=\"picture\">#{q.number}</div>" }
  end

  # The options with no question and no a)/b)/c) letters, for teams to circle.
  def self.choices(round)
    rows = round.questions.map do |q|
      cells = (q.options || []).map { |opt| "<td>#{esc(opt)}</td>" }
      "<tr><td class=\"number\">#{q.number}</td>#{cells.join}</tr>"
    end
    "<table class=\"options-table\">#{rows.join}</table>"
  end

  # A numbered ruled line per question, with True / False beside it when the
  # round is that format.
  def self.lines(round, true_false: false)
    items = round.questions.map do
      if true_false
        "<li><span class=\"true-false\">True / False</span><span class=\"answer-line\"></span></li>"
      else
        "<li><span class=\"answer-line\"></span></li>"
      end
    end
    "<ol class=\"answer-lines\">#{items.join}</ol>"
  end
end
