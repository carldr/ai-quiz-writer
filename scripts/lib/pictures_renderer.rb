# frozen_string_literal: true

require_relative "sheet_renderer"

# The numbered image grid teams look at.
#
# It is the one sheet that is passed around a noisy room rather than written on,
# so it carries no answers, no quiz title and no team name — only the images and
# the numbers that match the boxes on the team sheet.
module PicturesRenderer
  extend SheetRenderer

  # Returns nil when the quiz has no picture round, which is what tells the CLI
  # not to write the file.
  def self.render(quiz)
    picture_rounds = quiz.rounds.select { |r| r.format == "picture" }
    return nil if picture_rounds.empty?

    body = +""
    picture_rounds.each do |r|
      body << round_header(r)
      body << picture_grid(r) { |q| picture_cell(q.image, q.number) }
    end
    page("Pub Quiz — #{quiz.date} — Pictures", "pictures", body)
  end
end
