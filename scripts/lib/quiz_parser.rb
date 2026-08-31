# frozen_string_literal: true

require_relative "quiz"

# Turns a quiz.md file into a Quiz.
#
# The format is documented in docs/quiz-format.md. Parsing is strict and
# line-based: every non-blank line must be the header, the Total: line, a round
# heading, a Format: line, an Instructions: line, or a numbered question. A line
# that is none of those is an error rather than something to skip, because a
# question silently dropped from a printed sheet is worse than a failed render.
#
# Errors accumulate rather than raising on the first one, so a single run
# reports everything wrong with the file.
module QuizParser
  FORMATS = %w[picture multiple-choice open true-false].freeze

  # "## Round 3: Hidden Body Parts (/ 10)"
  ROUND_RE = /\A## Round (\d+): (.+?) \(\/ ?(\d+)\)\z/

  # "1. **The Shining** — images/r1-05.jpg" — answer first, then the image.
  PICTURE_Q_RE = /\A(\d+)\. \*\*(.+)\*\* — (images\/\S+)\z/

  # "1. Which came first? a) One b) Two — **b) Two**" — question, then answer.
  # The separator is an em dash (U+2014), not a hyphen.
  TEXT_Q_RE = /\A(\d+)\. (.+) — \*\*(.+)\*\*\z/

  # Parses the text of a quiz.md. `quiz_dir` is the directory it was read from;
  # when given, every picture question's image is checked to exist. Raises
  # ParseError listing every problem found.
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
      when /\A\s*\z/
        # blank line, ignore
      else
        errors << "line #{lineno}: unrecognized line: #{line.inspect}"
      end
    end

    errors << "line 1: missing '# Pub Quiz — YYYY-MM-DD' header" unless date
    rounds.each do |r|
      errors << "line #{r.line}: Round #{r.number} is missing its Format: line" unless r.format
    end
    raise ParseError, errors.join("\n") unless errors.empty?

    Quiz.new(date: date, total: total, rounds: rounds)
  end

  # A question line is read according to the format of the round it sits in, so a
  # question appearing before its round's Format: line cannot be parsed at all.
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
      q = Question.new(number: m[1].to_i, text: m[2], answer: m[3], line: lineno)
      q.text, q.options = split_options(m[2]) if round.format == "multiple-choice"
      round.questions << q
    else
      errors << "line #{lineno}: question has no bold answer after an em dash"
    end
  end

  # Splits on the space before each "a) ", "b) " and so on.
  OPTION_RE = /\s(?=[a-d]\) )/

  # Multiple-choice options are written inline as "Question? a) One b) Two".
  # Returns the question on its own and the option texts with their letters
  # stripped. A line with no inline options keeps its whole text and gets none,
  # which lets a multiple-choice round carry a question whose options the
  # quizmaster reads out rather than printing.
  def self.split_options(text)
    parts = text.split(OPTION_RE)
    return [text, []] if parts.length < 2

    [parts.first, parts.drop(1).map { |p| p.sub(/\A[a-d]\)\s*/, "").strip }]
  end
end
