require 'octokit'
require 'active_support/all'
require 'uri'

module Iceboxer
  class Template

    def initialize(repo)
      @repo = repo
    end

    def perform
      Octokit.auto_paginate = true

      # close issues that lack a template
      closers.each do |closer|
        issues = Octokit.search_issues(closer[:search])
        puts "#{@repo}: [TEMPLATE] Found #{issues.items.count} issues..."
        issues.items.each do |issue|
          unless already_nagged?(issue.number)
            puts "Processing #{issue.html_url}: #{issue.title}"
            templateNag(issue.number, closer)
          end
        end
      end
    end

    def closers
      [
        {
          :search => "repo:#{@repo} is:issue is:open created:>=2018-03-01 NOT \"Environment\" in:body NOT \"cherry-pick\" in:title -label:\"For Discussion\" comments:<3 -label:\"Core Team\" -label:\"Documentation\" -label:\"For Stack Overflow :question:\" -label:\"Good first issue\" -label:\"No Template :clipboard:\""
        }
      ]
    end

    def already_nagged?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /Issue Template/ }
    end

    def templateNag(issue, reason)
      Octokit.add_comment(@repo, issue, message("there"))
      Octokit.add_labels_to_an_issue(@repo, issue, ["No Template :clipboard:"])
      # No longer close issues
      # Octokit.close_issue(@repo, issue)

      puts "Template nagged #{@repo}/issues/#{issue}!"
    end

    def message(reason)
      <<-MSG.strip_heredoc
      Thanks for posting this! It looks like your issue may be incomplete. Are all the fields required by the [Issue Template](https://raw.githubusercontent.com/facebook/react-native/master/.github/ISSUE_TEMPLATE.md) filled out?
      
      If you believe your issue contains all the relevant information, let us know in order to have a maintainer remove the No Template label. Thank you for your contributions.
      
      <sub>[How to Contribute](https://facebook.github.io/react-native/docs/contributing.html#bugs) • [What to Expect from Maintainers](https://facebook.github.io/react-native/docs/maintainers.html#handling-issues)</sub>

      MSG
    end
  end
end
