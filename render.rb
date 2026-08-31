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
