#!/usr/bin/env ruby
# frozen_string_literal: true

# Sync upstream graphql-ruby guides into src/content/docs/ (Starlight format).
# Usage: ruby scripts/sync_upstream.rb

require "fileutils"
require "open3"
require "tmpdir"
require "yaml"

REPO_URL  = "https://github.com/rmosolgo/graphql-ruby.git"
PROJECT_ROOT = File.expand_path("..", __dir__)
DOCS_DIR = File.join(PROJECT_ROOT, "src", "content", "docs")

EXCLUDED_DIRS = %w[_layouts _plugins _sass _tasks css js].freeze
EXCLUDED_FILES = %w[_config.yml CNAME].freeze
EXCLUDED_EXTS = %w[.html .png].freeze

# ---------------------------------------------------------------------------
# Git clone
# ---------------------------------------------------------------------------
def clone_upstream(clone_dir)
  puts "Shallow cloning #{REPO_URL} into #{clone_dir}..."
  out, status = Open3.capture2e("git", "clone", "--depth", "1", REPO_URL, clone_dir)
  unless status.success?
    abort "git clone failed:\n#{out}"
  end
end

# ---------------------------------------------------------------------------
# File collection
# ---------------------------------------------------------------------------
def collect_md_files(guides_dir)
  Dir.glob(File.join(guides_dir, "**", "*.md")).select { |f| include_file?(f, guides_dir) }
end

def include_file?(path, guides_dir)
  rel = path.sub("#{guides_dir}/", "")

  # Skip files in excluded directories
  parts = rel.split("/")
  return false if parts.any? { |p| EXCLUDED_DIRS.include?(p) }

  # Skip excluded filenames
  basename = File.basename(rel)
  return false if EXCLUDED_FILES.include?(basename)

  # Skip excluded extensions (should not match .md but just in case)
  return false if EXCLUDED_EXTS.include?(File.extname(basename))

  true
end

# ---------------------------------------------------------------------------
# Frontmatter conversion (Jekyll -> Starlight)
# ---------------------------------------------------------------------------
DELETE_KEYS = %w[layout doc_stub search section other].freeze

def convert_frontmatter(raw_yaml, path:)
  data = YAML.safe_load(raw_yaml) || {}

  starlight = {}

  # title
  starlight["title"] = data["title"] if data["title"]

  # desc -> description
  starlight["description"] = data["desc"] if data["desc"]

  # index -> sidebar.order
  if data["index"]
    starlight["sidebar"] = { "order" => data["index"].to_i }
  end

  # Everything else that's not deleted or already handled
  handled = %w[title desc index] + DELETE_KEYS
  data.each do |k, v|
    next if handled.include?(k)
    starlight[k] = v
  end

  starlight
rescue Psych::Exception => e
  abort "frontmatter parse failed: #{path}\n#{e.message}"
end

def dump_frontmatter(hash)
  return "" if hash.empty?
  YAML.dump(hash).sub(/\A---\n/, "").chomp
end

# ---------------------------------------------------------------------------
# Jekyll template tag conversion
# ---------------------------------------------------------------------------

def convert_template_tags(body)
  text = body.dup

  # {% internal_link "text", "/path" %}
  text.gsub!(/\{%\s*internal_link\s+"([^"]+)"\s*,\s*"([^"]+)"\s*,?\s*%\}/) do
    "[#{$1}](#{$2})"
  end

  # {{ "ClassName" | api_doc }}
  text.gsub!(/\{\{\s*"([^"]+)"\s*\|\s*api_doc\s*\}\}/) do
    klass = $1
    "[`#{klass}`](https://graphql-ruby.org/api-doc/#{klass})"
  end

  text
end

# ---------------------------------------------------------------------------
# Process a single file
# ---------------------------------------------------------------------------
def process_file(src_path)
  content = File.read(src_path)

  # Split frontmatter and body
  if content =~ /\A---\r?\n(.*?)\r?\n---\r?\n(.*)\z/m
    raw_fm = $1
    body   = $2
  else
    raw_fm = nil
    body   = content
  end

  # Convert frontmatter
  if raw_fm
    starlight_fm = convert_frontmatter(raw_fm, path: src_path)
    fm_str = dump_frontmatter(starlight_fm)
    new_content = fm_str.empty? ? body : "---\n#{fm_str}\n---\n#{body}"
  else
    new_content = body
  end

  # Convert template tags
  new_content = convert_template_tags(new_content)

  new_content
end

# ---------------------------------------------------------------------------
# Write output
# ---------------------------------------------------------------------------
def write_output(src_path, content, guides_dir)
  rel = src_path.sub("#{guides_dir}/", "")
  dest = File.join(DOCS_DIR, rel)

  FileUtils.mkdir_p(File.dirname(dest))
  File.write(dest, content)
  puts "  wrote #{dest.sub("#{PROJECT_ROOT}/", "")}"
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main
  Dir.mktmpdir("graphql-ruby-") do |clone_dir|
    clone_upstream(clone_dir)

    guides_dir = File.join(clone_dir, "guides")
    unless Dir.exist?(guides_dir)
      abort "guides/ directory not found in cloned repo"
    end

    files = collect_md_files(guides_dir)
    puts "Found #{files.size} markdown files to sync."

    files.each do |src|
      content = process_file(src)
      write_output(src, content, guides_dir)
    end

    puts "\nDone! #{files.size} files synced to src/content/docs/"
  end
end

main
