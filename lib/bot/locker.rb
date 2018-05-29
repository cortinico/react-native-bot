require 'octokit'
require 'active_support/all'

module Bot
  class Locker

    def initialize(repo)
      @repo = repo
    end

    def perform
      candidates.each do |candidate|
        Octokit.auto_paginate = true
        issues = Octokit.search_issues(candidate[:search])
        puts "#{@repo}: [LOCKERS] [#{candidate[:lock_message]}] Found #{issues.items.count} issues to lock..."
        issues.items.each do |issue|
          lock(issue, candidate)
        end
      end
    end

    def candidates
      [
        {
          :search => "repo:#{@repo} is:issue is:closed label:\"Stale\"  closed:>=#{2.day.ago.to_date.to_s}",
          :lock_message => "Closed and Marked Stale",
          :lock_reason => "resolved"
        },
        {
          :search => "repo:#{@repo} is:issue is:closed closed:<=#{4.year.ago.to_date.to_s}",
          :lock_message => "Closed Over Four Years Ago",
          :lock_reason => "resolved"
        },
        {
          :search => "repo:#{@repo} is:issue is:closed closed:<=#{3.year.ago.to_date.to_s}",
          :lock_message => "Closed Over Three Years Ago",
          :lock_reason => "resolved"
        },
        {
          :search => "repo:#{@repo} is:issue is:closed closed:<=#{2.year.ago.to_date.to_s}",
          :lock_message => "Closed Over Two Years Ago",
          :lock_reason => "resolved"
        },
        {
          :search => "repo:#{@repo} is:issue is:closed closed:<=#{1.year.ago.to_date.to_s}",
          :lock_message => "Closed Over a Year Ago",
          :lock_reason => "resolved"
        }
      ]
    end

    def lock(issue, reason)
      unless issue.locked
        Octokit.lock_issue(@repo, issue.number, { :lock_reason => reason[:lock_reason], :accept => "application/vnd.github.sailor-v-preview+json" })

        puts "#{@repo}: [LOCKERS] 🔒 #{issue.html_url}: #{issue.title} --> #{reason[:lock_message]}"
      end
    end
  end
end
