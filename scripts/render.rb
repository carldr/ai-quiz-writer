#!/usr/bin/env ruby
# frozen_string_literal: true

# Renders a quiz into printable sheets.
#
#   ruby scripts/render.rb quizzes/2026-09-01
#
# The argument is the quiz directory; quiz.md inside it is implied. Three sheets
# are written to its out/ subdirectory — answers, questions, team and pictures — as both
# HTML and PDF, and the PDFs are copied to iCloud Drive under the quiz date.
#
# The work is in scripts/lib/:
#
#   quiz.rb               the Quiz, Round and Question structs, and the two errors
#   quiz_parser.rb        quiz.md text in, a Quiz out
#   sheet_renderer.rb     the HTML document and round heading the sheets share
#   answers_renderer.rb   a Quiz in, the quizmaster's HTML out
#   questions_renderer.rb a Quiz in, the questions without answers as HTML out
#   team_renderer.rb      a Quiz in, the team's HTML out
#   pictures_renderer.rb  a Quiz in, the image grid's HTML out
#   cli.rb                reads the directory, writes the files, drives Chrome
#
# The stylesheets are in scripts/render/: common.css, then one named after each
# sheet.
#
# The file format is documented in docs/quiz-format.md.

require_relative "lib/cli"

if __FILE__ == $PROGRAM_NAME
  dir = ARGV[0] or abort "usage: ruby scripts/render.rb quizzes/YYYY-MM-DD"
  begin
    *pdfs, copied = Cli.run(dir)
    pdfs.each { |p| puts p }
    puts "copied to #{copied}"
  rescue ParseError => e
    abort "#{dir}/quiz.md:\n#{e.message}"
  rescue RenderError => e
    abort e.message
  end
end
