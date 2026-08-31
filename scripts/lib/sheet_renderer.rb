# frozen_string_literal: true

require "cgi"
require_relative "quiz"

# The parts all three sheets share: the HTML document, the stylesheet each one
# loads, and the round heading that appears on every sheet.
#
# A sheet renderer picks this up with `extend SheetRenderer`, which puts these on
# the module itself so its own `def self.` methods can call them unqualified.
module SheetRenderer
  # The stylesheets live in scripts/render/. common.css holds what all three
  # sheets use and is inlined first; each sheet's own file follows and holds only
  # what that sheet needs, so it can override a common rule. Both are inlined
  # rather than linked, so a rendered HTML file in out/ stands on its own and can
  # be tweaked and reprinted by hand.
  CSS_DIR = File.expand_path("../render", __dir__)

  def stylesheet(name)
    @stylesheets ||= {}
    @stylesheets[name] ||= File.read(File.join(CSS_DIR, "#{name}.css"))
  rescue Errno::ENOENT
    raise RenderError, "no stylesheet at #{File.join(CSS_DIR, "#{name}.css")}"
  end

  def esc(text) = CGI.escapeHTML(text.to_s)

  def page(title, stylesheet_name, body)
    <<~HTML
      <!DOCTYPE html>
      <html><head><meta charset="utf-8"><title>#{esc(title)}</title>
      <style>#{stylesheet("common")}#{stylesheet(stylesheet_name)}</style></head>
      <body>#{body}</body></html>
    HTML
  end

  # The sheet title, with whatever goes on the right of it.
  def sheet_header(left, right)
    "<h1 class=\"sheet-header\"><span>#{left}</span><span>#{right}</span></h1>"
  end

  # The answer sheet and the team sheet both put each round on its own page, so
  # the quizmaster reads from one sheet while a table works on the matching one.
  # Every round but the last carries the break, so neither sheet ends on a blank
  # page. The block fills one round.
  def paged_rounds(rounds)
    last = rounds.length - 1
    rounds.each_with_index.map do |round, i|
      "<section#{i == last ? "" : " class=\"page-break\""}>" \
        "#{round_header(round)}#{yield round}</section>"
    end.join
  end

  # A picture round is the same grid on all three sheets — three cells across the
  # page, every cell 4:3 — so the numbers fall in the same places on the sheet
  # teams look at and the sheet they write on. The block fills one cell per
  # question.
  def picture_grid(round)
    cells = round.questions.map { |q| yield q }
    "<div class=\"picture-grid\">#{cells.join}</div>"
  end

  # One cell of that grid. Every cell is labelled with its number, wherever it is
  # printed; the answer sheet adds the answer on the line below. The image goes
  # behind the label on the two sheets that show the images, and an empty cell is
  # the same element as a filled one, so the cells line up across all three.
  def picture_cell(number, answer: nil, image: nil)
    img = image ? "<img src=\"../#{esc(image)}\">" : ""
    label = +"<span>#{number}</span>"
    label << "<span>#{answer}</span>" if answer
    "<figure class=\"picture\">#{img}<figcaption>#{label}</figcaption></figure>"
  end

  # The round title and its score box. The instructions line is printed on the
  # team sheet so teams know what to write, and on the answer sheet so the
  # quizmaster reads out the same thing.
  def round_header(round)
    h = +"<h2 class=\"round-header\"><span>Round #{round.number} - #{esc(round.name)}</span>" \
         "<span>__ / #{round.points}</span></h2>"
    h << "<p class=\"instructions\">#{esc(round.instructions)}</p>" if round.instructions
    h
  end
end
