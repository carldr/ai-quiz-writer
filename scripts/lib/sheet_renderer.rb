# frozen_string_literal: true

require "cgi"
require_relative "quiz"

# The parts all three sheets share: the HTML document, the stylesheet each one
# loads, and the round heading that appears on every sheet.
#
# A sheet renderer picks this up with `extend SheetRenderer`, which puts these on
# the module itself so its own `def self.` methods can call them unqualified.
module SheetRenderer
  # The stylesheets live in scripts/render/. common.css holds what all three
  # sheets use and is inlined first; each sheet's own file follows and holds only
  # what that sheet needs, so it can override a common rule. Both are inlined
  # rather than linked, so a rendered HTML file in out/ stands on its own and can
  # be tweaked and reprinted by hand.
  CSS_DIR = File.expand_path("../render", __dir__)

  def stylesheet(name)
    @stylesheets ||= {}
    @stylesheets[name] ||= File.read(File.join(CSS_DIR, "#{name}.css"))
  rescue Errno::ENOENT
    raise RenderError, "no stylesheet at #{File.join(CSS_DIR, "#{name}.css")}"
  end

  def esc(text) = CGI.escapeHTML(text.to_s)

  def page(title, stylesheet_name, body)
    <<~HTML
      <!DOCTYPE html>
      <html><head><meta charset="utf-8"><title>#{esc(title)}</title>
      <style>#{stylesheet("common")}#{stylesheet(stylesheet_name)}</style></head>
      <body>#{body}</body></html>
    HTML
  end

  # The sheet title, with whatever goes on the right of it.
  def sheet_header(left, right)
    "<h1 class=\"sheet-header\"><span>#{left}</span><span>#{right}</span></h1>"
  end

  # The round title and its score box. The instructions line is printed on the
  # team sheet so teams know what to write, and on the answer sheet so the
  # quizmaster reads out the same thing.
  def round_header(round)
    h = +"<h2 class=\"round-header\"><span>Round #{round.number} - #{esc(round.name)}</span>" \
         "<span>__ / #{round.points}</span></h2>"
    h << "<p class=\"instructions\">#{esc(round.instructions)}</p>" if round.instructions
    h
  end
end
