#!/usr/bin/env ruby
# frozen_string_literal: true

# Translate English Markdown guides to Japanese using OpenAI API.
# Usage: ruby scripts/translate.rb [options]
#
# Environment:
#   OPENAI_API_KEY  Required. Set in .env file or as environment variable.
#
# Examples:
#   ruby scripts/translate.rb
#   ruby scripts/translate.rb --dry-run
#   ruby scripts/translate.rb --file getting_started.md

require "yaml"
require "json"
require "net/http"
require "uri"
require "optparse"
require "fileutils"
require "digest"

# ---------------------------------------------------------------------------
# .env loader
# ---------------------------------------------------------------------------
def load_dotenv
  env_path = File.join(File.expand_path("..", __dir__), ".env")
  return unless File.exist?(env_path)

  File.foreach(env_path) do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")
    key, value = line.split("=", 2)
    ENV[key] = value if key && value && !ENV.key?(key)
  end
end

load_dotenv

PROJECT_ROOT = File.expand_path("..", __dir__)
DOCS_DIR = File.join(PROJECT_ROOT, "src", "content", "docs")
JA_DIR = File.join(DOCS_DIR, "ja")
PROGRESS_FILE = File.join(PROJECT_ROOT, ".translation_progress.json")

OPENAI_API_URL = "https://api.openai.com/v1/chat/completions"

# Approximate token costs per model (USD per 1M tokens)
MODEL_COSTS = {
  "gpt-4o" => { input: 2.50, output: 10.00 },
  "gpt-4o-mini" => { input: 0.15, output: 0.60 },
  "gpt-5-mini" => { input: 0.25, output: 2.00 },
}.freeze

# HTTP status codes that should NOT be retried (client errors, auth errors)
NON_RETRYABLE_CODES = %w[400 401 403 404].freeze

SYSTEM_PROMPT = <<~PROMPT
  あなたは技術文書の翻訳者です。英語の Markdown 本文を日本語に翻訳してください。

  ## 入出力形式

  入力の先頭に以下のメタデータ行がある場合、値を翻訳して同じ形式で出力の先頭に含めてください:
  - `TRANSLATE_TITLE: ...`
  - `TRANSLATE_DESCRIPTION: ...`

  メタデータ行の後に空行を 1 つ挟んで、翻訳された本文を出力してください。
  frontmatter (`---` で囲まれた YAML ブロック) は出力に含めないでください。

  ## 翻訳ルール

  1. **コードブロック** (``` で囲まれた部分): 一切変更しない。コード内容、コメント、diff ブロック、すべてそのまま保持する。
  2. **インラインコード** (`バッククォート`で囲まれた部分): 翻訳しない。
  3. **リンク**: URL はそのまま保持する。表示テキストは翻訳する。ただしクラス名・メソッド名 (例: `GraphQL::Schema`) が表示テキストの場合は翻訳しない。
  4. **テンプレートタグ**: `{{ }}` や `{% %}` はそのまま保持する。
  5. **HTML タグ**: そのまま保持する。
  6. **技術用語**: 以下の用語は英語のまま残す（訳さない）:
     schema, field, resolver, mutation, subscription, query, type, interface, union, scalar, enum,
     argument, directive, input object, connection, edge, node, Relay, Dataloader, GraphQL-Ruby,
     introspection, authorization, middleware, plugin, hook, multiplex, batch, trace, tracing,
     lazy, loader, source, cache, broadcast, trigger, channel
  7. **見出し方針**: 見出しは日本語に翻訳し、文書内で方針を統一する（英語見出しと日本語見出しを混在させない）。
  8. **アンカー整合性**: `#...` を含むリンクは、参照先見出しと整合するようにフラグメントを調整する。特に同一ファイル内リンク（`#...`）は必ず有効な見出しを参照させる。
  9. **文体**: です/ます調で統一する。不自然な直訳は避け、技術文書として自然で簡潔な日本語にする。
  10. **改行・空行**: 原文の構造をできるだけ維持する。
  11. **最終自己確認**: 出力前に、(a) コードブロック不変、(b) URL不変、(c) 見出し方針の一貫性、(d) 同一ファイル内アンカーの整合性を確認する。
PROMPT

# ---------------------------------------------------------------------------
# CLI Options
# ---------------------------------------------------------------------------
Options = Struct.new(:force, :file, :dry_run, :model, :clean, :verbose, keyword_init: true)

def parse_options
  opts = Options.new(force: false, file: nil, dry_run: false, model: "gpt-5-mini", clean: false, verbose: false)

  OptionParser.new do |o|
    o.banner = "Usage: ruby scripts/translate.rb [options]"
    o.on("--force", "Overwrite existing translations") { opts.force = true }
    o.on("--file PATH", "Translate a single file (e.g. schema/definition.md)") { |v| opts.file = v }
    o.on("--dry-run", "Show target files and cost estimate without calling API") { opts.dry_run = true }
    o.on("--model MODEL", "OpenAI model (default: gpt-5-mini)") { |v| opts.model = v }
    o.on("--clean", "Clear progress file and start fresh") { opts.clean = true }
    o.on("--verbose", "Verbose logging") { opts.verbose = true }
  end.parse!

  opts
end

# ---------------------------------------------------------------------------
# File collection
# ---------------------------------------------------------------------------
def validate_file_option!(path)
  abort "Error: --file path must not contain '..'" if path.include?("..")
  abort "Error: --file must not target ja/ directory" if path.start_with?("ja/") || path.start_with?("ja\\")
  abort "Error: --file must be a .md file" unless path.end_with?(".md")
end

def collect_source_files(single_file = nil)
  if single_file
    validate_file_option!(single_file)
    path = File.join(DOCS_DIR, single_file)
    abort "File not found: #{path}" unless File.exist?(path)
    [path]
  else
    Dir.glob(File.join(DOCS_DIR, "**", "*.md"))
       .reject { |f| f.start_with?("#{JA_DIR}/") || f.start_with?("#{JA_DIR}\\") }
       .sort
  end
end

def relative_path(full_path)
  full_path.sub("#{DOCS_DIR}/", "")
end

# ---------------------------------------------------------------------------
# Frontmatter handling (Pattern A: script-side separation)
# ---------------------------------------------------------------------------
def split_frontmatter(content)
  if content =~ /\A---\r?\n(.*?)\r?\n---\r?\n(.*)\z/m
    raw_yaml = $1
    body = $2
    fm = YAML.safe_load(raw_yaml) || {}
    [fm, body]
  else
    [{}, content]
  end
rescue Psych::Exception => e
  warn "  Warning: Failed to parse frontmatter: #{e.message}"
  [{}, content]
end

def dump_frontmatter(hash)
  return nil if hash.empty?
  YAML.dump(hash).sub(/\A---\n/, "").chomp
end

def build_output_content(frontmatter, body)
  fm_str = dump_frontmatter(frontmatter)
  if fm_str
    "---\n#{fm_str}\n---\n#{body}"
  else
    body
  end
end

# ---------------------------------------------------------------------------
# Translation input/output building
# ---------------------------------------------------------------------------
def build_translation_input(body, title: nil, description: nil)
  lines = []
  lines << "TRANSLATE_TITLE: #{title}" if title
  lines << "TRANSLATE_DESCRIPTION: #{description}" if description
  lines << "" if lines.any?
  lines << body
  lines.join("\n")
end

def parse_translation_output(text, has_title:, has_description:)
  lines = text.lines
  translated_title = nil
  translated_description = nil
  body_start = 0

  lines.each_with_index do |line, i|
    stripped = line.strip
    if has_title && translated_title.nil? && stripped.start_with?("TRANSLATE_TITLE:")
      translated_title = stripped.sub(/\ATRANSLATE_TITLE:\s*/, "")
      body_start = i + 1
    elsif has_description && translated_description.nil? && stripped.start_with?("TRANSLATE_DESCRIPTION:")
      translated_description = stripped.sub(/\ATRANSLATE_DESCRIPTION:\s*/, "")
      body_start = i + 1
    elsif stripped.empty? && body_start == i
      body_start = i + 1
    else
      break
    end
  end

  translated_body = lines[body_start..]&.join || ""
  translated_body = translated_body.sub(/\A\n+/, "")

  [translated_title, translated_description, translated_body]
end

# ---------------------------------------------------------------------------
# Progress tracking
# ---------------------------------------------------------------------------
def load_progress
  return {} unless File.exist?(PROGRESS_FILE)
  JSON.parse(File.read(PROGRESS_FILE))
rescue JSON::ParserError
  {}
end

def save_progress(progress)
  tmp = "#{PROGRESS_FILE}.tmp"
  File.write(tmp, JSON.pretty_generate(progress))
  File.rename(tmp, PROGRESS_FILE)
end

def file_sha256(path)
  Digest::SHA256.hexdigest(File.read(path))
end

def should_translate?(rel_path, progress, opts)
  return true if opts.force

  src_path = File.join(DOCS_DIR, rel_path)
  ja_path = File.join(JA_DIR, rel_path)
  current_sha = file_sha256(src_path)

  entry = progress[rel_path]

  if entry.nil?
    # No progress record — skip if ja file already exists
    return !File.exist?(ja_path)
  end

  return true if entry["status"] == "failed"
  return true if entry["sha256"] != current_sha

  false
end

# ---------------------------------------------------------------------------
# Token estimation (rough: 1 token ≈ 4 chars for English)
# ---------------------------------------------------------------------------
def estimate_tokens(text)
  (text.length / 4.0).ceil
end

# ---------------------------------------------------------------------------
# Code block extraction (line-by-line parser for robustness)
# ---------------------------------------------------------------------------
def extract_fenced_blocks(text)
  blocks = []
  current_block = nil

  text.each_line do |line|
    if current_block
      current_block << line
      if line.match?(/\A```\s*$/)
        blocks << current_block.join
        current_block = nil
      end
    elsif line.match?(/\A```/)
      current_block = [line]
    end
  end

  blocks
end

def strip_code_blocks(text)
  result = []
  in_block = false

  text.each_line do |line|
    if in_block
      in_block = false if line.match?(/\A```\s*$/)
    elsif line.match?(/\A```/)
      in_block = true
    else
      result << line
    end
  end

  result.join
end

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
def extract_link_urls(text)
  strip_code_blocks(text).scan(/\[.*?\]\((.*?)\)/).flatten
end

def validate_translation(source_body, translated_body)
  errors = []

  # Code block exact comparison
  src_blocks = extract_fenced_blocks(source_body)
  tgt_blocks = extract_fenced_blocks(translated_body)

  if src_blocks.size != tgt_blocks.size
    errors << "Code block count mismatch: source=#{src_blocks.size}, translated=#{tgt_blocks.size}"
  else
    src_blocks.zip(tgt_blocks).each_with_index do |(src, tgt), i|
      if src.strip != tgt.strip
        errors << "Code block ##{i + 1} content differs"
      end
    end
  end

  # Link URL count
  src_urls = extract_link_urls(source_body)
  tgt_urls = extract_link_urls(translated_body)
  if src_urls.size != tgt_urls.size
    errors << "Link URL count mismatch: source=#{src_urls.size}, translated=#{tgt_urls.size}"
  end

  errors
end

# ---------------------------------------------------------------------------
# OpenAI API
# ---------------------------------------------------------------------------
def call_openai(content, api_key, model, verbose: false)
  uri = URI(OPENAI_API_URL)

  body = {
    model: model,
    messages: [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: content },
    ],
  }

  max_retries = 3
  retry_count = 0
  backoff_times = [2, 8, 30]

  loop do
    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 30
      http.read_timeout = 120

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{api_key}"
      request.body = JSON.generate(body)

      response = http.request(request)
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError,
           OpenSSL::SSL::SSLError, Errno::ECONNRESET, Errno::ECONNREFUSED => e
      retry_count += 1
      if retry_count > max_retries
        return { error: "Network error after #{max_retries} retries: #{e.class}: #{e.message}" }
      end
      wait = backoff_times[retry_count - 1]
      warn "  Network error (#{e.class}). Retrying in #{wait}s..." if verbose
      sleep(wait)
      next
    end

    if response.code == "200"
      data = JSON.parse(response.body)
      usage = data["usage"] || {}
      translated = data.dig("choices", 0, "message", "content")

      if translated.nil? || translated.strip.empty?
        return { error: "Empty response content from API" }
      end

      return { text: translated, usage: usage }
    end

    # Non-retryable client/auth errors — fail immediately
    if NON_RETRYABLE_CODES.include?(response.code)
      return { error: "API error #{response.code}: #{response.body}" }
    end

    # Retryable errors (429, 5xx)
    retry_count += 1
    if retry_count > max_retries
      return { error: "API error after #{max_retries} retries: #{response.code} #{response.body}" }
    end

    if response.code == "429"
      retry_after = response["Retry-After"]&.to_i || backoff_times[retry_count - 1]
      warn "  Rate limited. Waiting #{retry_after}s..." if verbose
      sleep(retry_after)
    else
      wait = backoff_times[retry_count - 1]
      warn "  API error #{response.code}. Retrying in #{wait}s..." if verbose
      sleep(wait)
    end
  end
end

# ---------------------------------------------------------------------------
# Translate a single file
# ---------------------------------------------------------------------------
def translate_file(src_path, api_key, model, verbose:)
  content = File.read(src_path, encoding: "UTF-8")
  frontmatter, body = split_frontmatter(content)

  title = frontmatter["title"]
  description = frontmatter["description"]

  # Build API input: body + title/description markers (frontmatter is NOT sent)
  input = build_translation_input(body, title: title, description: description)

  result = call_openai(input, api_key, model, verbose: verbose)
  return result if result[:error]

  # Parse API output
  translated_title, translated_desc, translated_body = parse_translation_output(
    result[:text],
    has_title: !title.nil?,
    has_description: !description.nil?
  )

  # Validate translated body against source body
  validation_errors = validate_translation(body, translated_body)
  if validation_errors.any?
    return { error: "Validation failed: #{validation_errors.join('; ')}", usage: result[:usage] }
  end

  # Reconstruct frontmatter: preserve all keys, only replace title/description
  ja_fm = frontmatter.dup
  ja_fm["title"] = translated_title if title && translated_title
  ja_fm["description"] = translated_desc if description && translated_desc

  final = build_output_content(ja_fm, translated_body)
  { text: final, usage: result[:usage] }
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main
  opts = parse_options

  if opts.clean
    File.delete(PROGRESS_FILE) if File.exist?(PROGRESS_FILE)
    puts "Progress file cleared."
  end

  # Model validation
  unless MODEL_COSTS.key?(opts.model)
    warn "Warning: Unknown model '#{opts.model}'. Cost estimates will be unavailable."
  end

  api_key = ENV["OPENAI_API_KEY"]
  unless api_key || opts.dry_run
    abort "Error: OPENAI_API_KEY environment variable is not set.\n" \
          "Usage: Set OPENAI_API_KEY in .env or as environment variable."
  end

  source_files = collect_source_files(opts.file)
  progress = load_progress

  # Determine files to translate
  targets = source_files.select { |f| should_translate?(relative_path(f), progress, opts) }

  if targets.empty?
    puts "All files are already translated. Use --force to re-translate."
    return
  end

  # Cost estimation
  total_input_tokens = 0
  total_output_tokens = 0
  targets.each do |f|
    content = File.read(f, encoding: "UTF-8")
    input_tokens = estimate_tokens(SYSTEM_PROMPT) + estimate_tokens(content)
    output_tokens = estimate_tokens(content)
    total_input_tokens += input_tokens
    total_output_tokens += output_tokens
  end

  costs = MODEL_COSTS[opts.model]
  estimated_cost = if costs
    (total_input_tokens * costs[:input] / 1_000_000.0) +
    (total_output_tokens * costs[:output] / 1_000_000.0)
  end

  fmt = ->(n) { n.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,') }

  puts "=== Translation Plan ==="
  puts "Model:               #{opts.model}"
  puts "Files to process:    #{targets.size} / #{source_files.size}"
  puts "Approx. input tokens:  #{fmt.call(total_input_tokens)}"
  puts "Approx. output tokens: #{fmt.call(total_output_tokens)}"
  puts "Approx. cost:        #{estimated_cost ? "$#{'%.2f' % estimated_cost}" : '(unknown model)'}"
  puts ""

  if opts.dry_run
    puts "=== Target Files ==="
    targets.each do |f|
      rel = relative_path(f)
      status = progress.dig(rel, "status") || "new"
      puts "  #{rel} (#{status})"
    end
    return
  end

  # Translation loop
  translated_count = 0
  failed_count = 0
  total_usage = { "prompt_tokens" => 0, "completion_tokens" => 0, "total_tokens" => 0 }

  targets.each_with_index do |src_path, idx|
    rel = relative_path(src_path)
    puts "[#{idx + 1}/#{targets.size}] Translating #{rel}..."

    result = translate_file(src_path, api_key, opts.model, verbose: opts.verbose)

    if result[:error]
      warn "  ERROR: #{result[:error]}"
      progress[rel] = { "status" => "failed", "error" => result[:error], "sha256" => file_sha256(src_path) }
      if result[:usage]
        %w[prompt_tokens completion_tokens total_tokens].each { |k| total_usage[k] += result[:usage][k].to_i }
      end
      save_progress(progress)
      failed_count += 1
      next
    end

    usage = result[:usage]
    %w[prompt_tokens completion_tokens total_tokens].each { |k| total_usage[k] += usage[k].to_i }

    # Write translated file
    dest_path = File.join(JA_DIR, rel)
    FileUtils.mkdir_p(File.dirname(dest_path))
    File.write(dest_path, result[:text], mode: "w:UTF-8")
    puts "  -> #{dest_path.sub("#{PROJECT_ROOT}/", "")}"

    # Update progress
    progress[rel] = {
      "status" => "completed",
      "sha256" => file_sha256(src_path),
      "tokens" => usage,
    }
    save_progress(progress)
    translated_count += 1
  end

  # Summary
  actual_cost = if costs
    (total_usage["prompt_tokens"] * costs[:input] / 1_000_000.0) +
    (total_usage["completion_tokens"] * costs[:output] / 1_000_000.0)
  end

  puts ""
  puts "=== Summary ==="
  puts "Translated: #{translated_count}"
  puts "Failed:     #{failed_count}"
  puts "Tokens:     #{total_usage["prompt_tokens"]} input / #{total_usage["completion_tokens"]} output / #{total_usage["total_tokens"]} total"
  puts "Cost:       #{actual_cost ? "$#{'%.4f' % actual_cost}" : '(unknown model)'}"
end

main
