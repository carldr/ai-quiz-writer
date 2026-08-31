require "minitest/autorun"
require_relative "../scripts/render"

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

  def test_parses_multiple_choice_question_splitting_the_options_off
    q = parse_fixture.rounds[1].questions[0]
    assert_equal "Which is the largest wine bottle size?", q.text
    assert_equal ["Magnum", "Midas (30 litres)", "Nebuchadnezzar"], q.options
    assert_equal "b) Midas (30 litres)", q.answer
  end

  def test_a_question_outside_a_multiple_choice_round_gets_no_options
    q = parse_fixture.rounds[3].questions[0]
    assert_nil q.options
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

  def test_malformed_round_heading_is_an_error_not_silently_dropped
    text = HEADER + "## Round 1: X\n\nFormat: open\n\n1. Q? — **A**\n"
    assert_parse_error(text, "line 5: unrecognized line:")
  end

  def test_all_errors_reported_together
    text = HEADER + "## Round 1: X (/ 5)\n\nFormat: musical\n\n1. no answer here\n"
    err = assert_raises(ParseError) { QuizParser.parse(text) }
    assert_equal 2, err.message.lines.size
  end
end

class AnswersRendererTest < Minitest::Test
  def html
    quiz = QuizParser.parse(File.read(File.join(FIXTURE_DIR, "quiz.md")), quiz_dir: FIXTURE_DIR)
    AnswersRenderer.render(quiz)
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
    assert_includes html, "Round 2 - Size Matters"
    assert_includes html, "/ 2"
  end

  def test_answers_are_present_and_marked
    assert_includes html, "<strong>Bologna</strong>"
  end

  # A one-question multiple-choice quiz, for the answer-detail tests below.
  def choices_quiz(answer, options: ["Blue Peter", "Doctor Who"])
    Quiz.new(date: "2099-01-01", total: 1, rounds: [
      Round.new(number: 1, name: "X", points: 1, format: "multiple-choice", questions: [
        Question.new(number: 1, text: "Which came first?", options: options,
                     answer: answer, line: 1)
      ])
    ])
  end

  # The answer usually adds a date or a reason to the option it repeats. The
  # answer sheet prints the date or reason on a line of its own, and the option
  # alone in the options row.
  def test_multiple_choice_answer_detail_goes_below_the_options
    out = AnswersRenderer.render(choices_quiz("a) Blue Peter (1958, before Doctor Who)"))
    assert_includes out, "<strong>Blue Peter</strong>"
    assert_includes out, "<p class=\"answer-note\">1958, before Doctor Who</p>"
  end

  # An answer that adds nothing gets no note.
  def test_multiple_choice_answer_without_detail_gets_no_note
    out = AnswersRenderer.render(choices_quiz("a) Blue Peter"))
    assert_includes out, "<strong>Blue Peter</strong>"
    refute_includes out, "<p class=\"answer-note\">"
  end

  def test_multiple_choice_answer_adding_unbracketed_text_is_kept_whole
    out = AnswersRenderer.render(choices_quiz("a) Blue Peter, 1958"))
    assert_includes out, "<strong>Blue Peter, 1958</strong>"
    refute_includes out, "<p class=\"answer-note\">"
  end

  # ...and it must not reach the sheet the teams are looking at.
  def test_multiple_choice_answer_detail_stays_off_the_team_sheet
    quiz = choices_quiz("a) Blue Peter (1958, before Doctor Who)")
    refute_includes TeamRenderer.render(quiz), "1958"
    assert_includes TeamRenderer.render(quiz), "<td>Blue Peter</td>"
  end

  # The letter is printed beside the option already.
  def test_multiple_choice_answer_letter_is_not_printed_twice
    out = AnswersRenderer.render(choices_quiz("a) Blue Peter (1958)"))
    assert_includes out, "a)&nbsp; <strong>Blue Peter</strong>"
    refute_includes out, "<strong>a) Blue Peter"
  end

  # Only the lettered option is emboldened, so an answer written without a letter
  # leaves the options as they are rather than guessing at one.
  def test_multiple_choice_answer_without_a_letter_bolds_nothing
    out = AnswersRenderer.render(choices_quiz("Blue Peter"))
    refute_includes out, "<strong>"
  end

  def test_multiple_choice_answer_detail_is_escaped
    out = AnswersRenderer.render(choices_quiz("a) Blue Peter <b> & Co"))
    assert_includes out, "Blue Peter &lt;b&gt; &amp; Co"
  end

  def test_multiple_choice_bolds_the_correct_option_only
    assert_includes html, "<strong>Midas (30 litres)</strong>"
    refute_includes html, "<strong>Magnum</strong>"
    refute_includes html, "<strong>Nebuchadnezzar</strong>"
  end

  def test_multiple_choice_options_are_lettered_and_split_from_the_stem
    assert_includes html, "a)&nbsp; Magnum"
    assert_includes html, "c)&nbsp; Nebuchadnezzar"
    assert_includes html, "<li>Which is the largest wine bottle size?<div class=\"options\">"
  end

  def test_picture_round_answers_label_the_images
    assert_includes html, "<span class=\"picture-number\">1</span>" \
                          "<span class=\"picture-answer\">Dunlop</span>"
    assert_includes html, %(src="../images/r1-01.png")
  end

  def test_escapes_html_in_questions
    quiz = Quiz.new(date: "2099-01-01", total: 1, rounds: [
      Round.new(number: 1, name: "X", points: 1, format: "open", questions: [
        Question.new(number: 1, text: "What is <b>?", answer: "a & b", line: 1)
      ])
    ])
    out = AnswersRenderer.render(quiz)
    assert_includes out, "What is &lt;b&gt;?"
    assert_includes out, "a &amp; b"
  end
end

class TeamRendererTest < Minitest::Test
  def html
    quiz = QuizParser.parse(File.read(File.join(FIXTURE_DIR, "quiz.md")), quiz_dir: FIXTURE_DIR)
    TeamRenderer.render(quiz)
  end

  def test_has_team_name_line_and_no_answers
    assert_includes html, "Team"
    refute_includes html, "Bologna"
    refute_includes html, "Dunlop"
    refute_includes html, "<strong>"
  end

  # Teams hear the questions read out.
  def test_carries_no_question_text
    refute_includes html, "Which is the largest wine bottle size?"
    refute_includes html, "Mr Monopoly wears a monocle?"
    refute_includes html, "How many dots are on a standard six-sided dice?"
  end

  def test_multiple_choice_is_a_table_of_bare_options_to_circle
    assert_includes html, "<table class=\"options-table\">"
    assert_includes html, "<td>Nebuchadnezzar</td>"
    refute_includes html, "c) Nebuchadnezzar"
  end

  def test_true_false_offers_circling
    assert_includes html, "True / False"
  end

  def test_open_questions_get_numbered_ruled_lines
    assert_includes html, "<ol class=\"answer-lines\">"
    assert_includes html, "<span class=\"answer-line\"></span>"
  end

  def test_picture_round_is_numbered_empty_boxes_without_images
    refute_includes html, "r1-01.png"
    assert_includes html, "Round 1 - Logos"
    assert_includes html, "<figure class=\"picture\"><span class=\"picture-number\">1</span></figure>"
  end

  # The fixture has four rounds, so the first three break and the last does not.
  def test_every_round_but_the_last_starts_a_new_page
    assert_equal 3, html.scan("class=\"page-break\"").length
  end
end

class PicturesRendererTest < Minitest::Test
  def quiz
    QuizParser.parse(File.read(File.join(FIXTURE_DIR, "quiz.md")), quiz_dir: FIXTURE_DIR)
  end

  def test_grid_of_numbered_images_without_labels
    html = PicturesRenderer.render(quiz)
    assert_includes html, %(src="../images/r1-01.png")
    assert_includes html, "<span class=\"picture-number\">1</span>"
    refute_includes html, "Dunlop"
  end

  def test_nil_when_no_picture_round
    q = quiz
    q.rounds.reject! { |r| r.format == "picture" }
    assert_nil PicturesRenderer.render(q)
  end
end

require "tmpdir"
require "fileutils"

class CliTest < Minitest::Test
  def test_writes_html_files_to_out
    Dir.mktmpdir do |tmp|
      dir = File.join(tmp, "2099-01-01")
      FileUtils.cp_r(FIXTURE_DIR, dir)
      Cli.run(dir, pdf: false)
      %w[answers.html team.html pictures.html].each do |f|
        assert File.exist?(File.join(dir, "out", f)), "missing #{f}"
      end
    end
  end

  def test_parse_failure_aborts_with_line_numbers
    Dir.mktmpdir do |tmp|
      dir = File.join(tmp, "2099-01-01")
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "quiz.md"), "# Pub Quiz — 2099-01-01\n\nTotal: / 1\n\n## Round 1: X (/ 1)\n\nFormat: open\n\n1. broken\n")
      err = assert_raises(ParseError) { Cli.run(dir, pdf: false) }
      assert_includes err.message, "line 9"
    end
  end

  def test_missing_quiz_file_raises_render_error
    Dir.mktmpdir do |tmp|
      err = assert_raises(RenderError) { Cli.run(File.join(tmp, "nope"), pdf: false) }
      assert_includes err.message, "quiz.md"
    end
  end
end
