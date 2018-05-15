require 'octokit'
require 'active_support/all'

module Bot
  class Locker

    def initialize(repo)
      @repo = repo
    end

    def perform
      candidates.each do |candidate|
        issues = Octokit.search_issues(candidate[:search])
        puts "#{@repo}: [LOCKERS] [#{candidate[:lock_reason]}] Found #{issues.items.count} issues to lock..."
        issues.items.each do |issue|
          lock(issue, candidate)
        end
      end
    end

    def candidates
      [
        {
          :search => "repo:#{@repo} is:issue is:closed label:\"Stale\"  closed:>=#{2.day.ago.to_date.to_s}",
          :lock_reason => "Closed and Marked Stale"
        }
      ]
    end

    def lock(issue, reason)
      Octokit.lock_issue(@repo, issue.number)

      puts "#{@repo}: [LOCKERS] 🔒 #{issue.html_url}: #{issue.title} --> #{reason[:lock_reason]}"
    end
  end
end
