#!/usr/bin/env ruby
# frozen_string_literal: true

class ParseError < StandardError; end

Question = Struct.new(:number, :text, :answer, :image, :line, keyword_init: true)
Round = Struct.new(:number, :name, :points, :format, :instructions, :questions, :line, keyword_init: true)
Quiz = Struct.new(:date, :total, :rounds, keyword_init: true)

module QuizParser
  FORMATS = %w[picture multiple-choice open true-false].freeze
  ROUND_RE = /\A## Round (\d+): (.+?) \(\/ ?(\d+)\)\z/
  PICTURE_Q_RE = /\A(\d+)\. \*\*(.+)\*\* — (images\/\S+)\z/
  TEXT_Q_RE = /\A(\d+)\. (.+) — \*\*(.+)\*\*\z/

  def self.parse(text, quiz_dir: nil)
    errors = []
    date = nil
    total = nil
    rounds = []
    round = nil

    text.each_line.with_index(1) do |raw, lineno|
      line = raw.chomp
      case line
      when /\A# Pub Quiz — (\d{4}-\d{2}-\d{2})\z/
        date = Regexp.last_match(1)
      when /\ATotal: \/ ?(\d+)\z/
        total = Regexp.last_match(1).to_i
      when ROUND_RE
        round = Round.new(number: Regexp.last_match(1).to_i, name: Regexp.last_match(2),
                          points: Regexp.last_match(3).to_i, questions: [], line: lineno)
        rounds << round
      when /\AFormat: (.+)\z/
        value = Regexp.last_match(1).strip
        errors << "line #{lineno}: unknown Format: #{value.inspect}" unless FORMATS.include?(value)
        round.format = value if round
      when /\AInstructions: (.+)\z/
        round.instructions = Regexp.last_match(1) if round
      when /\A\d+\. /
        parse_question(line, lineno, round, quiz_dir, errors)
      end
    end

    errors << "line 1: missing '# Pub Quiz — YYYY-MM-DD' header" unless date
    rounds.each do |r|
      errors << "line #{r.line}: Round #{r.number} is missing its Format: line" unless r.format
    end
    raise ParseError, errors.join("\n") unless errors.empty?

    Quiz.new(date: date, total: total, rounds: rounds)
  end

  def self.parse_question(line, lineno, round, quiz_dir, errors)
    unless round&.format
      errors << "line #{lineno}: question before any round Format: line"
      return
    end
    if round.format == "picture"
      if (m = PICTURE_Q_RE.match(line))
        image = m[3]
        if quiz_dir && !File.exist?(File.join(quiz_dir, image))
          errors << "line #{lineno}: image file not found: #{image}"
        end
        round.questions << Question.new(number: m[1].to_i, answer: m[2], image: image, line: lineno)
      else
        errors << "line #{lineno}: picture question must be 'N. **Answer** — images/...'"
      end
    elsif (m = TEXT_Q_RE.match(line))
      round.questions << Question.new(number: m[1].to_i, text: m[2], answer: m[3], line: lineno)
    else
      errors << "line #{lineno}: question has no bold answer after an em dash"
    end
  end
end

require "cgi"

module SheetRenderer
  CSS = <<~CSS
    @page { size: A4; margin: 15mm; }
    body { font-family: -apple-system, Helvetica, Arial, sans-serif; font-size: 11pt; margin: 0; }
    h1 { font-size: 16pt; display: flex; justify-content: space-between; }
    h2 { font-size: 13pt; margin: 1.2em 0 0.3em; display: flex; justify-content: space-between;
         border-top: 1px solid #999; padding-top: 0.6em; }
    h2 .score { font-weight: normal; }
    ol { margin: 0.3em 0; padding-left: 1.6em; }
    li { margin: 0.35em 0; }
    .instructions { font-style: italic; margin: 0.2em 0; }
    .writein { border-bottom: 1px solid #666; display: inline-block; width: 60%; height: 1.1em; }
    .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 4mm; }
    .grid figure { margin: 0; text-align: center; }
    .grid img { width: 100%; height: 45mm; object-fit: cover; border: 1px solid #333; }
    .thumb { height: 12mm; vertical-align: middle; margin-left: 4px; }
  CSS

  def self.esc(text) = CGI.escapeHTML(text.to_s)

  def self.page(title, body)
    <<~HTML
      <!DOCTYPE html>
      <html><head><meta charset="utf-8"><title>#{esc(title)}</title>
      <style>#{CSS}</style></head>
      <body>#{body}</body></html>
    HTML
  end

  def self.round_header(round)
    h = +"<h2><span>Round #{round.number}: #{esc(round.name)}</span><span class=\"score\">__ / #{round.points}</span></h2>"
    h << "<p class=\"instructions\">#{esc(round.instructions)}</p>" if round.instructions
    h
  end

  def self.answers_html(quiz)
    body = +"<h1><span>Pub Quiz — #{esc(quiz.date)}</span><span>____ / #{quiz.total}</span></h1>"
    quiz.rounds.each do |r|
      body << round_header(r)
      body << "<ol>"
      r.questions.each do |q|
        if r.format == "picture"
          body << "<li><strong>#{esc(q.answer)}</strong><img class=\"thumb\" src=\"../#{esc(q.image)}\"></li>"
        else
          body << "<li>#{esc(q.text)} — <strong>#{esc(q.answer)}</strong></li>"
        end
      end
      body << "</ol>"
    end
    page("Pub Quiz — #{quiz.date} — Answers", body)
  end

  def self.team_html(quiz)
    body = +"<h1><span>Team <span class=\"writein\"></span></span><span>____ / #{quiz.total}</span></h1>"
    quiz.rounds.each do |r|
      body << round_header(r)
      body << "<ol>"
      r.questions.each do |q|
        body << case r.format
                when "picture" then "<li><span class=\"writein\"></span></li>"
                when "multiple-choice" then "<li>#{esc(q.text)}</li>"
                when "true-false" then "<li>#{esc(q.text)} &nbsp; True / False</li>"
                else "<li>#{esc(q.text)}<br><span class=\"writein\"></span></li>"
                end
      end
      body << "</ol>"
    end
    page("Pub Quiz — #{quiz.date} — Team Sheet", body)
  end

  def self.pictures_html(quiz)
    picture_rounds = quiz.rounds.select { |r| r.format == "picture" }
    return nil if picture_rounds.empty?

    body = +""
    picture_rounds.each do |r|
      body << round_header(r)
      body << "<div class=\"grid\">"
      r.questions.each do |q|
        body << "<figure><img src=\"../#{esc(q.image)}\"><figcaption>#{q.number}</figcaption></figure>"
      end
      body << "</div>"
    end
    page("Pub Quiz — #{quiz.date} — Pictures", body)
  end
end

module Cli
  CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

  def self.run(dir, pdf: true)
    quiz_md = File.join(dir, "quiz.md")
    abort "no quiz file at #{quiz_md}" unless File.exist?(quiz_md)
    quiz = QuizParser.parse(File.read(quiz_md), quiz_dir: dir)

    out = File.join(dir, "out")
    Dir.mkdir(out) unless Dir.exist?(out)

    sheets = {
      "answers" => SheetRenderer.answers_html(quiz),
      "team" => SheetRenderer.team_html(quiz),
      "pictures" => SheetRenderer.pictures_html(quiz)
    }.compact

    sheets.each { |name, html| File.write(File.join(out, "#{name}.html"), html) }

    if pdf
      raise "Chrome not found at #{CHROME}" unless File.exist?(CHROME)
      sheets.each_key do |name|
        html = File.join(out, "#{name}.html")
        target = File.join(out, "#{name}.pdf")
        ok = system(CHROME, "--headless", "--disable-gpu", "--no-pdf-header-footer",
                    "--print-to-pdf=#{target}", "file://#{File.expand_path(html)}",
                    out: File::NULL, err: File::NULL)
        raise "Chrome failed to print #{name}.pdf" unless ok && File.exist?(target)
      end
    end
    sheets.keys.map { |name| File.join(out, "#{name}.pdf") }
  end
end

if __FILE__ == $PROGRAM_NAME
  args = ARGV.dup
  pdf = !args.delete("--no-pdf")
  dir = args[0] or abort "usage: ruby render.rb quizzes/YYYY-MM-DD [--no-pdf]"
  begin
    paths = Cli.run(dir, pdf: pdf)
    paths.each { |p| puts p } if pdf
  rescue ParseError => e
    abort "#{dir}/quiz.md:\n#{e.message}"
  end
end
