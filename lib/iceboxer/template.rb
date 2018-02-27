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
        puts "[TEMPLATE] Found #{issues.items.count} issues to nag in #{@repo} ..."
        issues.items.each do |issue|
          unless already_nagged?(issue.number)
            puts "Nagging https://github.com/#{@repo}/issues/#{issue.number}: #{issue.title}"

            templateNag(issue.number, closer)
          end
        end
      end
    end

    def closers
      [
        {
          # The latest template, with "Is this a bug report?", was introduced on June 27, 2017.
          :search => "repo:#{@repo} is:issue is:open created:>=2017-06-27 NOT \"Is this a bug report?\" in:body NOT \"cherry-pick\" in:title -label:\"For Discussion\" comments:<5 -label:\"Core Team\" -label:\"Documentation\" -label:\"Missing required information from template\" -label:\"Needs more information\" -label:\"For Stack Overflow\" -label:\"Icebox\" -label:\"Good First Task\" -label:\"no-template\" -label:\"No Template\""
        },
        {
          # Earlier than July, let's check if they at least have some sort of repro steps
          :search => "repo:#{@repo} is:issue is:open created:<2017-06-27 NOT \"reproduction\" in:body NOT \"cherry-pick\" in:title -label:\"For Discussion\" comments:<5 -label:\"Core Team\" -label:\"Documentation\" -label:\"Missing required information from template\" -label:\"Needs more information\" -label:\"For Stack Overflow\" -label:\"Icebox\" -label:\"Good First Task\""
        }
      ]
    end

    def already_nagged?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /Issue Template/ }
    end

    def templateNag(issue, reason)
      Octokit.add_comment(@repo, issue, message("there"))
      Octokit.update_issue(@repo, issue, :labels => ["No Template", "Ran Commands"])
      # Octokit.close_issue(@repo, issue)

      puts "Template nagged #{@repo}/issues/#{issue}!"
    end

    def message(reason)
      <<-MSG.strip_heredoc
      Thanks for posting this! It looks like your issue may be missing some required information. Are all the fields required by the [Issue Template](https://raw.githubusercontent.com/facebook/react-native/master/.github/ISSUE_TEMPLATE.md) filled out?
      
      This is a friendly reminder and you may safely ignore this message if you believe your issue contains all the relevant information. Thank you for your contributions.
      
      <sub>[How to Contribute](https://facebook.github.io/react-native/docs/contributing.html#bugs) • [What to Expect from Maintainers](https://facebook.github.io/react-native/docs/maintainers.html#handling-issues)</sub>

      MSG
    end
  end
end
