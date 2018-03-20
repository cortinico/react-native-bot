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
            puts "#{@repo}: [TEMPLATE] Processing #{issue.html_url}: #{issue.title}"
            templateNag(issue, closer)
          end
        end
      end
    end

    def closers
      [
        {
          :search => "repo:#{@repo} is:issue is:open NOT \"Environment\" in:body NOT \"cherry-pick\" in:title -label:\"For Discussion\" -label:\":star2:Feature Request\" -label:\"Core Team\" -label:\":no_entry_sign:Docs\" -label:\":no_entry_sign:For Stack Overflow\" -label:\"Good first issue\" -label:\":clipboard:No Template\" comments:<3 created:>=2018-03-19"
        }
      ]
    end

    def already_nagged?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /Issue Template/ }
    end

    def templateNag(issue, reason)
      Octokit.add_comment(@repo, issue.number, message("there"))
      Octokit.add_labels_to_an_issue(@repo, issue.number, [":clipboard:No Template"])

      puts "#{@repo}: ️[TEMPLATE] ❗📋  #{issue.html_url}: #{issue.title} -> Missing template, nagged."
    end

    def message(reason)
      <<-MSG.strip_heredoc
      <!-- 
        {
          "nag_reason": "no-template"
        }
      -->
      Thanks for posting this! It looks like your issue may be incomplete. Are all the fields required by the [Issue Template](https://raw.githubusercontent.com/facebook/react-native/master/.github/ISSUE_TEMPLATE.md) filled out?
      
      If you believe your issue contains all the relevant information, let us know in order to have a maintainer remove the No Template label. Thank you for your contributions.
      
      <sub>[How to Contribute](https://facebook.github.io/react-native/docs/contributing.html#bugs) • [What to Expect from Maintainers](https://facebook.github.io/react-native/docs/maintainers.html#handling-issues)</sub>

      MSG
    end
  end
end
