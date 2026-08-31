# frozen_string_literal: true

require_relative "quiz"
require_relative "quiz_parser"
require_relative "answers_renderer"
require_relative "team_renderer"
require_relative "pictures_renderer"

# Reads a quiz directory and writes the sheets into its out/ subdirectory.
module Cli
  CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

  # Renders quizzes/YYYY-MM-DD. Writes an .html for each sheet, then prints each
  # to PDF unless `pdf` is false. Returns the PDF paths.
  #
  # The HTML is written first and the PDF made from the file on disk, rather than
  # piped, because Chrome must resolve the ../images/ paths relative to the
  # rendered file. That is also why the HTML files stay behind afterwards: a
  # one-off tweak can be made by hand and reprinted.
  def self.run(dir, pdf: true)
    quiz_md = File.join(dir, "quiz.md")
    raise RenderError, "no quiz file at #{quiz_md}" unless File.exist?(quiz_md)

    quiz = QuizParser.parse(File.read(quiz_md), quiz_dir: dir)

    out = File.join(dir, "out")
    Dir.mkdir(out) unless Dir.exist?(out)

    # compact drops the picture sheet when the quiz has no picture round.
    sheets = {
      "answers" => AnswersRenderer.render(quiz),
      "team" => TeamRenderer.render(quiz),
      "pictures" => PicturesRenderer.render(quiz)
    }.compact

    sheets.each { |name, html| File.write(File.join(out, "#{name}.html"), html) }

    print_pdfs(out, sheets.keys) if pdf
    sheets.keys.map { |name| File.join(out, "#{name}.pdf") }
  end

  # Headless Chrome is the only PDF step: it is already on the machine, and it is
  # the same engine the HTML was designed against.
  def self.print_pdfs(out, names)
    raise RenderError, "Chrome not found at #{CHROME}" unless File.exist?(CHROME)

    names.each do |name|
      html = File.join(out, "#{name}.html")
      target = File.join(out, "#{name}.pdf")
      ok = system(CHROME, "--headless", "--disable-gpu", "--no-pdf-header-footer",
                  "--print-to-pdf=#{target}", "file://#{File.expand_path(html)}",
                  out: File::NULL, err: File::NULL)
      raise RenderError, "Chrome failed to print #{name}.pdf" unless ok && File.exist?(target)
    end
  end
end
