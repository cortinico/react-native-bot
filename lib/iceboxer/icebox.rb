require 'octokit'
require 'active_support/all'
require 'uri'

module Iceboxer
  class Icebox

    def initialize(repo)
      @repo = repo
    end

    def perform
      Octokit.auto_paginate = true

      # close stale issues
      closers.each do |closer|
        issues = Octokit.search_issues(closer[:search])
        puts "[ICEBOX] Found #{issues.items.count} issues to close in #{@repo} ..."
        issues.items.each do |issue|
          unless already_iceboxed?(issue.number)
            puts "Closing https://github.com/#{@repo}/issues/#{issue.number}: #{issue.title}"

            icebox(issue.number, closer)
          end
        end
      end
    end

    def closers
      [
        {
          :search => "repo:#{@repo} is:open is:issue created:<#{12.months.ago.to_date.to_s} updated:<#{2.months.ago.to_date.to_s} -label:\"Good first issue\" -label:\"Help Wanted\" -label:\"For Discussion\""
        },
        {
          :search => "repo:#{@repo} is:open is:issue updated:<#{6.months.ago.to_date.to_s} -label:\"Good first issue\" -label:\"Help Wanted\" -label:\"For Discussion\""
        }
      ]
    end

    def already_iceboxed?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /Icebox/ }
    end

    def icebox(issue, reason)
      Octokit.add_comment(@repo, issue, message("none"))
      Octokit.update_issue(@repo, issue, :labels => "stale, Icebox, Ran Commands")
      Octokit.close_issue(@repo, issue)

      puts "Iceboxed #{@repo}/issues/#{issue}!"
    end

    def message(reason)
      <<-MSG.strip_heredoc
      This issue is being closed because it has been inactive for a while. This may indicate that the issue is no longer affecting people. It may very well still be affecting you. Either way, please do not take it personally.
      
      If you think this issue should definitely remain open, please let us know. The following information is helpful when it comes to determining if the issue should be re-opened: 
      
      <ul>
        <li>Does the issue still reproduce on the latest release candidate? Post a comment with the version you tested.</li>
        <li>If so, is there any information missing from the bug report? You may consider opening a new issue that provides all the necessary information outlined in the [issue template](https://github.com/facebook/react-native/blob/master/.github/ISSUE_TEMPLATE.md).</li>
        <li>Is there a pull request that addresses this issue? Post a comment with the PR number so we can follow up.</li>
      </ul>
      
      If you would like to work on a patch to fix the issue, *contributions are very welcome*! Read through the [contribution guide](https://facebook.github.io/react-native/docs/contributing.html), and feel free to hop into [#react-native](https://discordapp.com/invite/0ZcbPKXt5bZjGY5n) if you need help planning your contribution.
      
      <sub>[How to Contribute](https://facebook.github.io/react-native/docs/contributing.html#bugs) • [What to Expect from Maintainers](https://facebook.github.io/react-native/docs/maintainers.html#handling-issues)</sub>

      MSG
    end
  end
end
