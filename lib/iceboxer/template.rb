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
        puts "Found #{issues.items.count} issues to close in #{@repo} ..."
        issues.items.each do |issue|
          unless already_nagged?(issue.number)
            puts "Closing https://github.com/#{@repo}/issues/#{issue.number}: #{issue.title}"

            templateNag(issue.number, closer)
          end
        end
      end
    end

    def closers
      [
        {
          :search => "repo:#{@repo} is:issue is:open NOT \"Is this a bug report?\" in:body NOT \"cherry-pick\" in:title -label:\"For Discussion\" comments:0 -label:\"Core Team\" -label:\"Documentation\" -label:\"For Stack Overflow\" -label:\"Icebox\" -label:\"Good First Task\""
        }
      ]
    end

    def already_nagged?(issue)
      labels = Octokit.labels_for_issue(@repo, issue)
      labels.any? { |l| l =~ /Missing required information from template/ }
    end

    def templateNag(issue, reason)

      # # Perform as BOT
      Octokit.access_token = ENV['GITHUB_API_TOKEN_PUBLIC']
      Octokit.add_comment(@repo, issue, message(reason))

      # # Perform as HECTOR
      Octokit.access_token = ENV['GITHUB_API_TOKEN_WRITE']
      Octokit.add_labels_to_an_issue(@repo, issue, ["Missing required information from template", "Needs more information"])
      Octokit.close_issue(@repo, issue)

      puts "Template nagged #{@repo}/issues/#{issue}!"
    end

    def message(reason)
      <<-MSG.strip_heredoc
      Hey, thanks for reporting this issue!

      It looks like your description is missing some necessary information, or the list of reproduction steps is not complete. Can you please add all the details specified in the [template](https://github.com/facebook/react-native/blob/master/.github/ISSUE_TEMPLATE.md)? This is necessary for people to be able to understand and reproduce the issue being reported.

      I am going to close this, but feel free to open a new issue that meets the requirements set forth in the template. Thanks!
      MSG
    end
  end
end
