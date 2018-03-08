require 'octokit'
require 'active_support/all'
require 'uri'

module Iceboxer
  class OldVersion

    def initialize(repo)
      @repo = repo
    end

    def perform
      Octokit.auto_paginate = true

      # close issues that mention an old version
      closers.each do |closer|
        issues = Octokit.search_issues(closer[:search])
        puts "[OLD VERSION] Found #{issues.items.count} issues to nag in #{@repo} ..."
        issues.items.each do |issue|
          unless already_nagged?(issue.number)
            puts "Nagging https://github.com/#{@repo}/issues/#{issue.number}: #{issue.title}"

            oldVersionNag(issue.number, closer)
          else
            puts "Already nagged https://github.com/#{@repo}/issues/#{issue.number}"
          end
        end
      end
    end

    def closers
      [
        {
          :search => "repo:#{@repo} is:issue is:open created:>=2018-03-01 \"Environment\" in:body \"react-native: 0.53.3\" in:body -label:\"Core Team\"-label:\"Good first issue\" -label:\"Old Version :rewind:\""
        },
        {
          :search => "repo:#{@repo} is:issue is:open created:>=2018-03-01 \"Environment\" in:body \"react-native: 0.53.2\" in:body -label:\"Core Team\"-label:\"Good first issue\" -label:\"Old Version :rewind:\""
        },
        {
          :search => "repo:#{@repo} is:issue is:open created:>=2018-03-01 \"Environment\" in:body \"react-native: 0.53.1\" in:body -label:\"Core Team\"-label:\"Good first issue\" -label:\"Old Version :rewind:\""
        },
        {
          :search => "repo:#{@repo} is:issue is:open created:>=2018-03-01 \"Environment\" in:body \"react-native: 0.53.0\" in:body -label:\"Core Team\"-label:\"Good first issue\" -label:\"Old Version :rewind:\""
        },

        {
          :search => "repo:#{@repo} is:issue is:open created:>=2018-03-01 \"Environment\" in:body \"react-native: 0.52.0\" in:body -label:\"Core Team\"-label:\"Good first issue\" -label:\"Old Version :rewind:\""
        },
        {
          :search => "repo:#{@repo} is:issue is:open created:>=2018-02-01 \"Environment\" in:body \"react-native: 0.51.0\" in:body -label:\"Core Team\"-label:\"Good first issue\" -label:\"Old Version :rewind:\""
        },
        {
          :search => "repo:#{@repo} is:issue is:open created:>=2018-02-01 \"Environment\" in:body \"react-native: 0.50.4\" in:body -label:\"Core Team\"-label:\"Good first issue\" -label:\"Old Version :rewind:\""
        },
        {
          :search => "repo:#{@repo} is:issue is:open created:>=2018-02-01 \"Environment\" in:body \"react-native: 0.50.3\" in:body -label:\"Core Team\"-label:\"Good first issue\" -label:\"Old Version :rewind:\""
        },
        {
          :search => "repo:#{@repo} is:issue is:open created:>=2018-02-01 \"Environment\" in:body \"react-native: 0.50.2\" in:body -label:\"Core Team\"-label:\"Good first issue\" -label:\"Old Version :rewind:\""
        },
        {
          :search => "repo:#{@repo} is:issue is:open created:>=2018-02-01 \"Environment\" in:body \"react-native: 0.50.1\" in:body -label:\"Core Team\"-label:\"Good first issue\" -label:\"Old Version :rewind:\""
        },
        {
          :search => "repo:#{@repo} is:issue is:open created:>=2018-02-01 \"Environment\" in:body \"react-native: 0.50.0\" in:body -label:\"Core Team\"-label:\"Good first issue\" -label:\"Old Version :rewind:\""
        },
        {
          :search => "repo:#{@repo} is:issue is:open created:>=2018-02-01 \"Environment\" in:body \"react-native: 0.49.0\" in:body -label:\"Core Team\"-label:\"Good first issue\" -label:\"Old Version :rewind:\""
        }
      ]
    end

    def already_nagged?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /latest stable release/ }
    end

    def oldVersionNag(issue, reason)
      Octokit.add_comment(@repo, issue, message("there"))
      Octokit.add_labels_to_an_issue(@repo, issue, ["Old Version", "Ran Commands"])
      # No longer close issues
      # Octokit.close_issue(@repo, issue)

      puts "Old-version nagged #{@repo}/issues/#{issue}!"
    end

    def message(reason)
      <<-MSG.strip_heredoc
      Thanks for posting this! It looks like your issue may refer to an older version of React Native. Can you reproduce the issue on the [latest stable release](http://facebook.github.io/react-native/versions.html)?
      
      Thank you for your contributions.
      
      <sub>[How to Contribute](https://facebook.github.io/react-native/docs/contributing.html#bugs) • [What to Expect from Maintainers](https://facebook.github.io/react-native/docs/maintainers.html#handling-issues)</sub>

      MSG
    end
  end
end
