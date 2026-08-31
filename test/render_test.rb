require "minitest/autorun"
require_relative "../render"

FIXTURE_DIR = File.expand_path("fixture", __dir__)

class ParserTest < Minitest::Test
  def parse_fixture
    QuizParser.parse(File.read(File.join(FIXTURE_DIR, "quiz.md")), quiz_dir: FIXTURE_DIR)
  end

  def test_parses_header
    quiz = parse_fixture
    assert_equal "2099-01-01", quiz.date
    assert_equal 27, quiz.total
    assert_equal 4, quiz.rounds.size
  end

  def test_parses_round_metadata
    r = parse_fixture.rounds[1]
    assert_equal 2, r.number
    assert_equal "Size Matters", r.name
    assert_equal 2, r.points
    assert_equal "multiple-choice", r.format
    assert_equal "Circle your answers.", r.instructions
  end

  def test_instructions_are_optional
    assert_nil parse_fixture.rounds[3].instructions
  end

  def test_parses_open_question
    q = parse_fixture.rounds[3].questions[0]
    assert_equal 1, q.number
    assert_equal "In which city is Europe's oldest university?", q.text
    assert_equal "Bologna", q.answer
    assert_nil q.image
  end

  def test_parses_multiple_choice_question_keeping_options_in_text
    q = parse_fixture.rounds[1].questions[0]
    assert_includes q.text, "c) Nebuchadnezzar"
    assert_equal "b) Midas (30 litres)", q.answer
  end

  def test_parses_picture_question
    q = parse_fixture.rounds[0].questions[0]
    assert_equal "Dunlop", q.answer
    assert_equal "images/r1-01.png", q.image
    assert_nil q.text
  end
end

class ParserErrorTest < Minitest::Test
  def assert_parse_error(text, expected_fragment, quiz_dir: nil)
    err = assert_raises(ParseError) { QuizParser.parse(text, quiz_dir: quiz_dir) }
    assert_includes err.message, expected_fragment
  end

  HEADER = "# Pub Quiz — 2099-01-01\n\nTotal: / 5\n\n"

  def test_unknown_format_is_an_error_with_line_number
    text = HEADER + "## Round 1: X (/ 5)\n\nFormat: musical\n\n1. Q? — **A**\n"
    assert_parse_error(text, "line 7: unknown Format: \"musical\"")
  end

  def test_question_without_bold_answer_is_an_error
    text = HEADER + "## Round 1: X (/ 5)\n\nFormat: open\n\n1. Question with no answer\n"
    assert_parse_error(text, "line 9: question has no bold answer")
  end

  def test_missing_image_file_is_an_error
    text = HEADER + "## Round 1: X (/ 5)\n\nFormat: picture\n\n1. **A** — images/nope.png\n"
    assert_parse_error(text, "image file not found: images/nope.png", quiz_dir: FIXTURE_DIR)
  end

  def test_round_without_format_is_an_error
    text = HEADER + "## Round 1: X (/ 5)\n\n1. Q? — **A**\n"
    assert_parse_error(text, "line 5: Round 1 is missing its Format: line")
  end

  def test_missing_header_is_an_error
    assert_parse_error("Total: / 5\n", "missing '# Pub Quiz")
  end

  def test_all_errors_reported_together
    text = HEADER + "## Round 1: X (/ 5)\n\nFormat: musical\n\n1. no answer here\n"
    err = assert_raises(ParseError) { QuizParser.parse(text) }
    assert_equal 2, err.message.lines.size
  end
end

class AnswersSheetTest < Minitest::Test
  def html
    quiz = QuizParser.parse(File.read(File.join(FIXTURE_DIR, "quiz.md")), quiz_dir: FIXTURE_DIR)
    SheetRenderer.answers_html(quiz)
  end

  def test_is_a_complete_html_document
    assert_match(/\A<!DOCTYPE html>/i, html)
    assert_includes html, "</html>"
  end

  def test_has_title_and_total
    assert_includes html, "Pub Quiz — 2099-01-01"
    assert_includes html, "/ 27"
  end

  def test_round_headings_with_score_boxes
    assert_includes html, "Round 2: Size Matters"
    assert_includes html, "/ 2"
  end

  def test_answers_are_present_and_marked
    assert_includes html, "<strong>Bologna</strong>"
    assert_includes html, "<strong>b) Midas (30 litres)</strong>"
  end

  def test_picture_round_answers_listed_with_thumbnails
    assert_includes html, "<strong>Dunlop</strong>"
    assert_includes html, %(src="../images/r1-01.png")
  end

  def test_escapes_html_in_questions
    quiz = Quiz.new(date: "2099-01-01", total: 1, rounds: [
      Round.new(number: 1, name: "X", points: 1, format: "open", questions: [
        Question.new(number: 1, text: "What is <b>?", answer: "a & b", line: 1)
      ])
    ])
    out = SheetRenderer.answers_html(quiz)
    assert_includes out, "What is &lt;b&gt;?"
    assert_includes out, "a &amp; b"
  end
end

class TeamSheetTest < Minitest::Test
  def html
    quiz = QuizParser.parse(File.read(File.join(FIXTURE_DIR, "quiz.md")), quiz_dir: FIXTURE_DIR)
    SheetRenderer.team_html(quiz)
  end

  def test_has_team_name_line_and_no_answers
    assert_includes html, "Team"
    refute_includes html, "Bologna"
    refute_includes html, "Dunlop"
    refute_includes html, "<strong>"
  end

  def test_multiple_choice_keeps_options
    assert_includes html, "c) Nebuchadnezzar"
  end

  def test_true_false_offers_circling
    assert_includes html, "True / False"
    assert_includes html, "Mr Monopoly wears a monocle?"
  end

  def test_open_questions_get_write_in_lines
    assert_includes html, "How many dots are on a standard six-sided dice?"
    assert_includes html, "writein"
  end

  def test_picture_round_is_numbered_write_in_lines_without_images
    refute_includes html, "r1-01.png"
    assert_includes html, "Round 1: Logos"
  end
end
