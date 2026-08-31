# Quiz Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Ruby renderer that turns a markdown quiz file into three printable sheets (quizmaster answers, team answer sheet, picture sheet), plus a `/new-quiz` Claude Code skill that generates quizzes round by round.

**Architecture:** One stdlib-only Ruby script, `render.rb`, containing a strict parser (quiz.md → structs) and three HTML generators sharing one CSS block; PDFs are produced from the HTML by headless Chrome. Generation logic lives entirely in a project skill, not in code.

**Tech Stack:** Ruby 4.0.1 (stdlib only; minitest for tests), Google Chrome headless for PDF.

**Spec:** docs/superpowers/specs/2026-08-31-quiz-generator-design.md

## Global Constraints

- Ruby standard library only — no gems beyond bundled minitest, nothing to install.
- Ruby is at `/usr/bin/env ruby` (4.0.1, arm64-darwin27); Chrome at `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`.
- Quiz layout: `quizzes/YYYY-MM-DD/quiz.md`, `quizzes/YYYY-MM-DD/images/`, `quizzes/YYYY-MM-DD/out/`.
- `Format:` values: exactly `picture`, `multiple-choice`, `open`, `true-false`.
- The em dash `—` (U+2014) separates question from answer; the answer is the final bold segment.
- Parse errors are hard failures naming line numbers.
- PDFs are A4.
- Commit after each task; commit messages have no Co-Authored-By lines.
- All tests run with: `ruby test/render_test.rb`.

---

### Task 1: Parser happy path

**Files:**
- Create: `render.rb`
- Create: `test/render_test.rb`
- Create: `test/fixture/quiz.md`
- Create: `test/fixture/images/r1-01.png`, `test/fixture/images/r1-02.png` (any tiny PNG)

**Interfaces:**
- Produces: `QuizParser.parse(text, quiz_dir:)` → `Quiz` struct; structs `Quiz(date, total, rounds)`, `Round(number, name, points, format, instructions, questions)`, `Question(number, text, answer, image, line)` (all `keyword_init: true`); `ParseError < StandardError`. `render.rb` is requirable (CLI guarded by `if __FILE__ == $PROGRAM_NAME`).

- [ ] **Step 1: Create the fixture quiz**

`test/fixture/quiz.md`:

```markdown
# Pub Quiz — 2099-01-01

Total: / 27

## Round 1: Logos (/ 2)

Format: picture
Instructions: Identify the brand from a cropped logo.

1. **Dunlop** — images/r1-01.png
2. **Whiskas** — images/r1-02.png

## Round 2: Size Matters (/ 2)

Format: multiple-choice
Instructions: Circle your answers.

1. Which is the largest wine bottle size? a) Magnum b) Midas (30 litres) c) Nebuchadnezzar — **b) Midas (30 litres)**
2. Which is further? a) 1 astronomical unit b) 1 light year c) 1 parsec — **c) 1 parsec (3.26 light years)**

## Round 3: True or False (/ 3)

Format: true-false

1. Bees have five eyes? — **True**
2. You can sneeze in your sleep? — **False**
3. Mr Monopoly wears a monocle? — **False**

## Round 4: General Knowledge (/ 20)

Format: open

1. In which city is Europe's oldest university? — **Bologna**
2. How many dots are on a standard six-sided dice? — **21**
```

Create the two image files (a 1×1 PNG is fine):

```bash
mkdir -p test/fixture/images
printf '\x89PNG\r\n\x1a\n' > test/fixture/images/r1-01.png
cp test/fixture/images/r1-01.png test/fixture/images/r1-02.png
```

(The parser only checks existence, never content.)

- [ ] **Step 2: Write the failing test**

`test/render_test.rb`:

```ruby
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
```

- [ ] **Step 3: Run test to verify it fails**

Run: `ruby test/render_test.rb`
Expected: FAIL — cannot load `../render` (file does not exist).

- [ ] **Step 4: Implement the parser**

`render.rb`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

class ParseError < StandardError; end

Question = Struct.new(:number, :text, :answer, :image, :line, keyword_init: true)
Round = Struct.new(:number, :name, :points, :format, :instructions, :questions, keyword_init: true)
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
                          points: Regexp.last_match(3).to_i, questions: [])
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
      errors << "Round #{r.number}: missing Format: line" unless r.format
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `ruby test/render_test.rb`
Expected: PASS (7 tests).

- [ ] **Step 6: Commit**

```bash
git add render.rb test
git commit -m "Add quiz.md parser with fixture"
```

---

### Task 2: Parser error cases

**Files:**
- Modify: `render.rb` (only if a test exposes a gap)
- Test: `test/render_test.rb`

**Interfaces:**
- Consumes: `QuizParser.parse`, `ParseError` from Task 1.
- Produces: nothing new — locks in the strict-error contract.

- [ ] **Step 1: Write the failing tests**

Append to `test/render_test.rb`:

```ruby
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
    assert_parse_error(text, "Round 1: missing Format: line")
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
```

- [ ] **Step 2: Run tests**

Run: `ruby test/render_test.rb`
Expected: mostly PASS already (Task 1 implemented the checks); fix `render.rb` for any failure. A question line before any round (`test_round_without_format` variant) must not crash with NoMethodError — the `unless round&.format` guard covers it.

- [ ] **Step 3: Commit**

```bash
git add test/render_test.rb render.rb
git commit -m "Lock in strict parser error contract"
```

---

### Task 3: Quizmaster answers sheet

**Files:**
- Modify: `render.rb`
- Test: `test/render_test.rb`

**Interfaces:**
- Consumes: `Quiz`/`Round`/`Question` structs from Task 1.
- Produces: `SheetRenderer.answers_html(quiz)` → String (complete HTML document). Shared private helpers `SheetRenderer.page(title, body_html)` and `SheetRenderer::CSS` used by Tasks 4–5. All question/answer text passes through `SheetRenderer.esc` (CGI escape).

- [ ] **Step 1: Write the failing tests**

Append to `test/render_test.rb`:

```ruby
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
    assert_includes html, %(<strong>Bologna</strong>)
    assert_includes html, %(<strong>b) Midas (30 litres)</strong>)
  end

  def test_picture_round_answers_listed_with_thumbnails
    assert_includes html, %(<strong>Dunlop</strong>)
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `ruby test/render_test.rb`
Expected: FAIL — `SheetRenderer` not defined.

- [ ] **Step 3: Implement**

Add to `render.rb`:

```ruby
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

  def self.answers_html(quiz)
    body = +"<h1><span>Pub Quiz — #{esc(quiz.date)}</span><span>____ / #{quiz.total}</span></h1>"
    quiz.rounds.each do |r|
      body << "<h2><span>Round #{r.number}: #{esc(r.name)}</span><span class=\"score\">__ / #{r.points}</span></h2>"
      body << "<p class=\"instructions\">#{esc(r.instructions)}</p>" if r.instructions
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
end
```

(Thumbnail `src` is `../images/...` because the HTML lives in `out/`, a sibling of `images/`.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `ruby test/render_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add render.rb test/render_test.rb
git commit -m "Add quizmaster answers sheet renderer"
```

---

### Task 4: Team answer sheet

**Files:**
- Modify: `render.rb`
- Test: `test/render_test.rb`

**Interfaces:**
- Consumes: `SheetRenderer.page`, `SheetRenderer.esc` from Task 3.
- Produces: `SheetRenderer.team_html(quiz)` → String.

Layout rules: team name line at the top; every round appears with its heading, score box, and instructions. Picture rounds: numbered write-in lines only (the images are on the separate picture sheet). Multiple-choice: full question text including options (answer stripped). True-false: question text plus "True / False" to circle. Open: question text plus a write-in line. No answers anywhere.

- [ ] **Step 1: Write the failing tests**

Append to `test/render_test.rb`:

```ruby
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `ruby test/render_test.rb`
Expected: FAIL — `team_html` not defined.

- [ ] **Step 3: Implement**

Add to `SheetRenderer`:

```ruby
def self.team_html(quiz)
  body = +"<h1><span>Team <span class=\"writein\"></span></span><span>____ / #{quiz.total}</span></h1>"
  quiz.rounds.each do |r|
    body << "<h2><span>Round #{r.number}: #{esc(r.name)}</span><span class=\"score\">__ / #{r.points}</span></h2>"
    body << "<p class=\"instructions\">#{esc(r.instructions)}</p>" if r.instructions
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `ruby test/render_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add render.rb test/render_test.rb
git commit -m "Add team answer sheet renderer"
```

---

### Task 5: Picture sheet

**Files:**
- Modify: `render.rb`
- Test: `test/render_test.rb`

**Interfaces:**
- Consumes: `SheetRenderer.page`, `SheetRenderer.esc`, `.grid` CSS from Task 3.
- Produces: `SheetRenderer.pictures_html(quiz)` → String. Renders every `picture` round (normally one); returns `nil` if the quiz has none.

- [ ] **Step 1: Write the failing tests**

Append to `test/render_test.rb`:

```ruby
class PictureSheetTest < Minitest::Test
  def quiz
    QuizParser.parse(File.read(File.join(FIXTURE_DIR, "quiz.md")), quiz_dir: FIXTURE_DIR)
  end

  def test_grid_of_numbered_images_without_labels
    html = SheetRenderer.pictures_html(quiz)
    assert_includes html, %(src="../images/r1-01.png")
    assert_includes html, "<figcaption>1</figcaption>"
    refute_includes html, "Dunlop"
  end

  def test_nil_when_no_picture_round
    q = quiz
    q.rounds.reject! { |r| r.format == "picture" }
    assert_nil SheetRenderer.pictures_html(q)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `ruby test/render_test.rb`
Expected: FAIL — `pictures_html` not defined.

- [ ] **Step 3: Implement**

Add to `SheetRenderer`:

```ruby
def self.pictures_html(quiz)
  picture_rounds = quiz.rounds.select { |r| r.format == "picture" }
  return nil if picture_rounds.empty?

  body = +""
  picture_rounds.each do |r|
    body << "<h2><span>Round #{r.number}: #{esc(r.name)}</span><span class=\"score\">__ / #{r.points}</span></h2>"
    body << "<p class=\"instructions\">#{esc(r.instructions)}</p>" if r.instructions
    body << "<div class=\"grid\">"
    r.questions.each do |q|
      body << "<figure><img src=\"../#{esc(q.image)}\"><figcaption>#{q.number}</figcaption></figure>"
    end
    body << "</div>"
  end
  page("Pub Quiz — #{quiz.date} — Pictures", body)
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `ruby test/render_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add render.rb test/render_test.rb
git commit -m "Add picture sheet renderer"
```

---

### Task 6: CLI and PDF generation

**Files:**
- Modify: `render.rb`
- Test: `test/render_test.rb` (CLI-callable pieces only; the Chrome step is verified manually)

**Interfaces:**
- Consumes: everything above.
- Produces: `Cli.run(dir, pdf: true)` — parses `dir/quiz.md`, writes `dir/out/{answers,team,pictures}.html`, then prints each to PDF. `CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"`. Command line: `ruby render.rb quizzes/YYYY-MM-DD` (add `--no-pdf` to skip Chrome, used by tests).

- [ ] **Step 1: Write the failing test**

Append to `test/render_test.rb`:

```ruby
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
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `ruby test/render_test.rb`
Expected: FAIL — `Cli` not defined.

- [ ] **Step 3: Implement**

Add to `render.rb`:

```ruby
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `ruby test/render_test.rb`
Expected: PASS.

- [ ] **Step 5: Manual end-to-end check**

```bash
mkdir -p quizzes/2099-01-01
cp test/fixture/quiz.md quizzes/2099-01-01/
cp -r test/fixture/images quizzes/2099-01-01/
ruby render.rb quizzes/2099-01-01
open quizzes/2099-01-01/out/answers.pdf
```

Expected: three PDFs exist, A4, answer sheet shows bold answers, team sheet has no answers, picture sheet is a numbered grid. Eyeball all three, then delete the sample: `rm -r quizzes/2099-01-01`.

- [ ] **Step 6: Commit**

```bash
git add render.rb test/render_test.rb
git commit -m "Add CLI and headless-Chrome PDF output"
```

---

### Task 7: /new-quiz skill

**Files:**
- Create: `.claude/skills/new-quiz/SKILL.md`

**Interfaces:**
- Consumes: `ruby render.rb quizzes/YYYY-MM-DD` from Task 6; quiz format per the spec.
- Produces: the `/new-quiz` slash command.

- [ ] **Step 1: Write the skill**

`.claude/skills/new-quiz/SKILL.md`:

```markdown
---
name: new-quiz
description: Generate a new pub quiz round by round, with web-verified answers, no repeats from past quizzes, and rendered printable sheets. Use when Carl asks to create/generate a quiz. Takes the quiz date as argument.
---

# New quiz

Generate a pub quiz for the date given as argument (ask if missing). Work
round by round; never move to the next round without approval.

## Structure

Default: Round 1 picture (15 questions, / 15), one or two multiple-choice
rounds (/ 10 each), one or two novelty rounds (/ 10 each), final round
general knowledge (20 questions, / 20). Total 75. Ask up front if Carl wants
a different shape or a theme (seasonal, event-based). NEVER propose music or
audio rounds.

Study `OLD-QUIZZES.md` for tone, difficulty, and the kinds of novelty rounds
used before (connections, anagrams, true/false, "X or Y?", single-letter
answers, headlines...). Novelty round formats may be reused; questions may not.

## Per round

1. Propose 2–3 round themes with a one-line description each. Carl picks.
2. Draft the full round in the quiz file format (see docs/quiz-format.md).
3. Verify EVERY answer with web search. Correct or replace any question whose
   answer cannot be confirmed; if kept despite doubt, flag it to Carl.
4. Dedupe: grep OLD-QUIZZES.md and every quizzes/*/quiz.md for each question's
   key fact (search for the answer and for distinctive question words, not the
   whole sentence). Replace any repeat — a question counts as repeated if it
   asks for the same fact, even worded differently.
5. Show the round to Carl. Apply requested swaps (re-verify and re-dedupe
   replacements) until approved.

## Picture round

After the 15 items are approved:
1. Fetch 2–3 candidate images per item into quizzes/YYYY-MM-DD/images/ as
   candidate-NN-a.jpg, candidate-NN-b.jpg, ...
2. Write quizzes/YYYY-MM-DD/images/contact-sheet.html showing all candidates
   with their filenames; tell Carl to open it and pick.
3. Copy each pick to the final name r1-NN.png/jpg matching the quiz file, and
   delete the unused candidates and the contact sheet.
Image rights are Carl's call — prefer official logos/promotional images and
say where each came from.

## Finish

1. Write quizzes/YYYY-MM-DD/quiz.md (format: docs/quiz-format.md).
2. Run: ruby render.rb quizzes/YYYY-MM-DD
3. Fix any parse errors, and report the three PDF paths.
```

- [ ] **Step 2: Verify the skill loads**

Confirm the file parses as a skill: frontmatter has `name` and `description`, body is plain markdown. (Verified in use in Task 8's smoke test — no automated test exists for skills.)

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/new-quiz/SKILL.md
git commit -m "Add /new-quiz generation skill"
```

---

### Task 8: Format documentation (main session only — NOT for a subagent)

**Files:**
- Create: `docs/quiz-format.md`

This is user-facing documentation, so it MUST follow Carl's documentation
process (`~/.claude/CLAUDE.md`), which includes user review — a subagent
cannot run it. The main session does this task interactively:

- [ ] **Step 1:** Extract the facts, one per line with source, from the spec's
  "Quiz file format" and "Renderer" sections (the spec is the source; lift
  wording verbatim where possible). Group under the headings the doc will
  have: File layout, Header, Rounds, Questions, Images, Rendering.
- [ ] **Step 2:** Keep the facts list outside the repo (scratchpad).
- [ ] **Step 3:** Run the prose judge:
  `PROSE_JUDGE_INPUT=<file> ~/.claude/hooks/prose-judge.sh`; fix findings.
- [ ] **Step 4:** Show Carl the facts list verbatim, in full, inline. Wait.
- [ ] **Step 5:** Render with the `doc-writer` agent (facts + audience: Carl
  and future Claude sessions writing quiz.md by hand).
- [ ] **Step 6:** Run `doc-check` with the same facts; act on findings.
- [ ] **Step 7:** Run `doc-read` with the audience; act on ORDER and MISSING.
- [ ] **Step 8:** Write to `docs/quiz-format.md`, then:

```bash
git add docs/quiz-format.md
git commit -m "Document the quiz file format"
```

- [ ] **Step 9 (smoke test):** Confirm `/new-quiz`'s references hold: the
  skill file cites `docs/quiz-format.md` and `ruby render.rb` — both must now
  exist and be accurate.
```
