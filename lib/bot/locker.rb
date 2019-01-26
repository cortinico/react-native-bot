require 'octokit'
require 'active_support/all'

module Bot
  class Locker

    def initialize(repo)
      @repo = repo
      @label_resolved = "Resolved"
      @label_stale = "Stale"
    end

    def perform
      candidates.each do |candidate|
        Octokit.auto_paginate = true
        issues = Octokit.search_issues(candidate[:search], { :per_page => 100 })
        issues.items.each do |issue|
          lock(issue, candidate)
        end
      end
    end

    def candidates
      [
        {
          :search => "repo:#{@repo} is:issue is:closed label:\"#{@label_stale}\" closed:>=#{2.day.ago.to_date.to_s}",
          :lock_message => "Closed and Marked Stale",
          :lock_reason => "resolved"
        },
        {
          :search => "repo:#{@repo} is:issue is:closed -label:\"#{@label_resolved}\" closed:<=#{1.year.ago.to_date.to_s}",
          :lock_message => "Closed, Not Tagged Resolved",
          :lock_reason => "resolved"
        }
      ]
    end

    def lock(issue, reason)
      unless issue.locked
        Octokit.lock_issue(@repo, issue.number, { :lock_reason => reason[:lock_reason], :accept => "application/vnd.github.sailor-v-preview+json" })
        puts "#{@repo}: [LOCKERS] 🔒 #{issue.html_url}: #{issue.title} --> #{reason[:lock_message]}"
      end
      add_labels(issue, [@label_resolved]) unless issue_contains_label(issue, @label_stale)
    end

    def add_labels(issue, labels)
      new_labels = []

      labels.each do |label|
        if label
          new_labels.push label unless issue_contains_label(issue, label)
        end
      end

      if new_labels.count > 0
        puts "#{@repo}: [LABELS] 📍 #{issue.html_url} --> Adding #{new_labels}"
        Octokit.add_labels_to_an_issue(@repo, issue.number, new_labels)
      end
    end

    def issue_contains_label(issue, label)
      existing_labels = []

      issue.labels.each do |issue_label|
        existing_labels.push issue_label.name if issue_label.name
      end

      existing_labels.include? label
    end
  end
end
