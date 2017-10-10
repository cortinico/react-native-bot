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
          :search => "repo:#{@repo} is:issue is:open created:>=2017-06-27 NOT \"Is this a bug report?\" in:body NOT \"cherry-pick\" in:title -label:\"For Discussion\" comments:<5 -label:\"Core Team\" -label:\"Documentation\" -label:\"Missing required information from template\" -label:\"Needs more information\" -label:\"For Stack Overflow\" -label:\"Icebox\" -label:\"Good First Task\" NOT \"relicense\" in:title"
        },
        {
          # Earlier than July, let's check if they at least have some sort of repro steps
          :search => "repo:#{@repo} is:issue is:open created:<2017-06-27 NOT \"reproduction\" in:body NOT \"cherry-pick\" in:title -label:\"For Discussion\" comments:<5 -label:\"Core Team\" -label:\"Documentation\" -label:\"Missing required information from template\" -label:\"Needs more information\" -label:\"For Stack Overflow\" -label:\"Icebox\" -label:\"Good First Task\" NOT \"relicense\" in:title"
        }

      ]
    end

    def already_nagged?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /no-template/ }
    end

    def templateNag(issue, reason)
      Octokit.add_comment(@repo, issue, "@facebook-github-bot no-template")

      puts "Template nagged #{@repo}/issues/#{issue}!"
    end
  end
end
