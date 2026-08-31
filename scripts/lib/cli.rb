# frozen_string_literal: true

require "fileutils"

require_relative "quiz"
require_relative "quiz_parser"
require_relative "answers_renderer"
require_relative "team_renderer"
require_relative "pictures_renderer"

# Reads a quiz directory and writes the sheets into its out/ subdirectory.
module Cli
  CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

  # The finished PDFs are copied here, into a directory named for the quiz date,
  # so they reach the phone and the printer without being fetched off the laptop.
  ICLOUD_QUIZ_DIR = File.join(Dir.home, "Library/Mobile Documents/com~apple~CloudDocs/Quiz")

  # Renders quizzes/YYYY-MM-DD. Writes an .html for each sheet, then prints each
  # to PDF and copies the PDFs to iCloud Drive, both unless `pdf` is false.
  # Returns the PDF paths in out/, followed by the iCloud directory they were
  # copied to.
  #
  # The HTML is written first and the PDF made from the file on disk, rather than
  # piped, because Chrome must resolve the ../images/ paths relative to the
  # rendered file. That is also why the HTML files stay behind afterwards: a
  # one-off tweak can be made by hand and reprinted.
  def self.run(dir, pdf: true, icloud_dir: ICLOUD_QUIZ_DIR)
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

    paths = sheets.keys.map { |name| File.join(out, "#{name}.pdf") }
    return paths unless pdf

    print_pdfs(out, sheets.keys)
    [*paths, copy_to_icloud(paths, quiz.date, icloud_dir)]
  end

  # Copies the finished PDFs into a directory named for the quiz date, replacing
  # whatever a previous render of the same quiz left there. Returns the
  # directory.
  #
  # A missing iCloud Drive is an error rather than something to create, because
  # the alternative is writing a directory tree nobody will ever look in.
  def self.copy_to_icloud(paths, date, icloud_dir)
    root = File.dirname(icloud_dir)
    raise RenderError, "no iCloud Drive at #{root}" unless Dir.exist?(root)

    target = File.join(icloud_dir, date)
    FileUtils.mkdir_p(target)
    paths.each { |path| FileUtils.cp(path, target) }
    target
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
