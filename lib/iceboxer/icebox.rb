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

      # edit older issues that got iceboxed, encourage contributions instead
      needUpdates.each do |reason|
        issues = Octokit.search_issues(reason[:search])
        puts "Found #{issues.items.count} issues to edit in #{@repo} ..."
        issues.items.each do |issue|
          unless already_edited?(issue.number)
            puts "Editing https://github.com/#{@repo}/issues/#{issue.number}: #{issue.title}"

            edit_canny_message(issue, reason[:message])
          end
        end

      end

      # close stale issues
      closers.each do |closer|
        issues = Octokit.search_issues(closer[:search])
        puts "Found #{issues.items.count} issues to close in #{@repo} ..."
        issues.items.each do |issue|
          unless already_iceboxed?(issue.number)
            puts "Closing https://github.com/#{@repo}/issues/#{issue.number}: #{issue.title}"

            icebox(issue.number, closer)
          end
        end
      end
    end

    def needUpdates
      [
        {
          :search => "repo:#{@repo} is:closed is:issue label:icebox",
          :message => "it has been inactive for a while"
        }
      ]
    end

    def closers
      [
        {
          :search => "repo:#{@repo} is:open is:issue updated:<#{2.months.ago.to_date.to_s}",
          :message => "it has been inactive for a while"
        }
      ]
    end

    def already_edited?(issueNumber)
      comments = Octokit.issue_comments(@repo, issueNumber)
      not_edited = comments.any? { |c| c.body =~ /Canny/ }

      !not_edited
    end

    def already_iceboxed?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /Icebox/ }
    end

    def edit_canny_message(issue, reason)
      comments = Octokit.issue_comments(@repo, issue.number)
      comments.each do |c|
        # The script was run with Héctor's access token. Only edit comments by Héctor that mention Canny.
        if c.body =~ /Canny/ && c.user.login == "hramos"
          Octokit.update_comment(@repo, c.id, message(reason))
          urls = URI.extract(c.body)
          urls.each do |u|
            # Just log this to the console for follow up.
            puts "To Delete: #{u}" if u =~ /canny.io/
          end
        end
      end
    end

    def icebox(issue, reason)
      Octokit.add_labels_to_an_issue(@repo, issue, ["Icebox"])
      Octokit.add_comment(@repo, issue, message(reason))
      Octokit.close_issue(@repo, issue)

      puts "Iceboxed #{@repo}/issues/#{issue}!"
    end

    # Not being used. We need a way to map canny.io URLs to post ids
    def delete_on_canny(post_url)
      company_name = ENV['CANNY_COMPANY_NAME']
      post_id = nil # we can't get the post_id from a post_url
      Iceboxer::Canny.delete_issue(company_name, post_id)
    end

    def message(reason)
      <<-MSG.strip_heredoc
      Hi there! This issue is being closed because #{reason}. Maybe the issue has been fixed in a recent release, or perhaps it is not affecting a lot of people. Either way, we're automatically closing issues after a period of inactivity. Please do not take it personally!

      If you think this issue should definitely remain open, please let us know. The following information is helpful when it comes to determining if the issue should be re-opened:

      - Does the issue still reproduce on the latest release candidate? Post a comment with the version you tested.
      - If so, is there any information missing from the bug report? Post a comment with all the information required by the [issue template](https://github.com/facebook/react-native/blob/master/.github/ISSUE_TEMPLATE.md).
      - Is there a pull request that addresses this issue? Post a comment with the PR number so we can follow up.

      If you would like to work on a patch to fix the issue, *contributions are very welcome*! Read through the [contribution guide](http://facebook.github.io/react-native/docs/contributing.html), and feel free to hop into [#react-native](https://discordapp.com/invite/0ZcbPKXt5bZjGY5n) if you need help planning your contribution.
      MSG
    end
  end
end
