#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'pathname'

errors = []

skills = if ARGV.any?
           ARGV.map { |arg| Pathname.new(arg) }.select { |p| p.directory? || p.file? }
         else
           Pathname.glob('skills/**/SKILL.md')
         end

# Expand directories to their SKILL.md files
skills = skills.flat_map do |path|
  if path.directory?
    Pathname.glob(path.join('SKILL.md'))
  elsif path.file? && path.basename.to_s == 'SKILL.md'
    [path]
  else
    []
  end
end.uniq

skills.each do |path|
  content = path.read
  next unless content.start_with?('---')

  # Extract only the frontmatter (between first and second ---)
  parts = content.split(/^---\s*$/, 3)
  if parts.length < 3
    errors << "#{path}: could not find frontmatter delimiters"
    next
  end

  frontmatter_yaml = parts[1]

  begin
    frontmatter = YAML.safe_load(frontmatter_yaml)

    unless frontmatter.is_a?(Hash)
      errors << "#{path}: frontmatter is not a hash"
      next
    end

    desc = frontmatter['description']
    if desc.nil? || desc.to_s.strip.empty?
      errors << "#{path}: description is empty"
    elsif desc.to_s.length > 1024
      errors << "#{path}: description is #{desc.to_s.length} chars (max 1024)"
    end

    %w[name type license].each do |key|
      errors << "#{path}: missing #{key}" if frontmatter[key].to_s.strip.empty?
    end
  rescue => e
    errors << "#{path}: YAML parse error: #{e.message}"
  end
end

if errors.any?
  puts "ERRORS:"
  errors.each { |e| puts " - #{e}" }
  exit 1
else
  puts "All #{skills.count} SKILL.md files have valid frontmatter descriptions."
end
