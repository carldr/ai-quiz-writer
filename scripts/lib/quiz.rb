# frozen_string_literal: true

# The data a quiz is made of, and the two errors the renderer raises.
#
# A quiz.md file parses into one Quiz holding an ordered list of Rounds, each
# holding an ordered list of Questions. Nothing here does any work: the parser
# fills these in, and the renderer reads them.

# Raised when quiz.md cannot be parsed. The message lists every problem found,
# one per line, each starting with the line number it was found on.
class ParseError < StandardError; end

# Raised when a quiz parses but cannot be turned into sheets — a missing file,
# a missing stylesheet, or Chrome failing to print.
class RenderError < StandardError; end

# One question.
#
# `text` is the question as it will be read out. For a multiple-choice question
# the inline options are split off into `options`, so `text` holds the question
# alone and `options` holds the choices with their a)/b)/c) letters stripped.
# Every other format leaves `options` nil.
#
# `answer` is the whole bold segment from the markdown, kept verbatim, because
# the quizmaster reads it out and it often carries an explanation. For a
# multiple-choice question it starts with the correct option's letter, and that
# letter is what tells the renderer which option to embolden.
#
# `image` is set on picture questions only, as a path relative to quiz.md.
# `line` is the line in quiz.md the question came from, for error messages.
Question = Struct.new(:number, :text, :answer, :image, :options, :line, keyword_init: true)

# One round. `format` is one of the four in QuizParser::FORMATS and decides how
# the round is laid out on each sheet. `instructions` is optional and is printed
# on both the team sheet and the answer sheet.
Round = Struct.new(:number, :name, :points, :format, :instructions, :questions, :line,
                   keyword_init: true)

# One quiz. `total` is the mark out of printed in the header; the parser does not
# check that the rounds add up to it.
Quiz = Struct.new(:date, :total, :rounds, keyword_init: true)
