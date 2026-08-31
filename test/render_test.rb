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
