require 'octokit'
require 'active_support/all'

module Iceboxer
  class Labeler

    def initialize(repo)
      @repo = repo
    end

    def perform
      candidates.each do |candidate|
        issues = Octokit.search_issues(candidate[:search])
        puts "[LABELER] Found #{issues.items.count} issues to label in #{@repo} ..."
        issues.items.each do |issue|
          puts "Labeling #{@repo}/issues/#{issue.number}: #{issue.title}"
          label(issue, candidate)
        end
      end
    end

    def candidates
      [
        {
          :search => "repo:#{@repo} is:issue is:open \"android\" in:title -label:\"Android\"",
          :label => "Android"
        },
        {
          :search => "repo:#{@repo} is:issue is:open \"ios\" in:title -label:\"iOS :iphone:\"",
          :label => "iOS :iphone:"
        }
      ]
    end

    def label(issue, candidate)
      Octokit.add_labels_to_an_issue(@repo, issue.number, ["Ran Commands", candidate[:label]])

      puts "Labeled #{issue.title}: #{candidate[:label]}"
    end
  end
end