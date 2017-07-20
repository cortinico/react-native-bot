require 'octokit'
require 'active_support/all'

module Iceboxer
  class Icebox

    def initialize(repo)
      @repo = repo
    end

    def perform
      closers.each do |closer|
        Octokit.auto_paginate = true
        issues = Octokit.search_issues(closer[:search])
        puts "Found #{issues.items.count} issues to close in #{@repo} ..."
        issues.items.each do |issue|
          unless already_iceboxed?(issue.number)
            puts "Closing #{@repo}/issues/#{issue.number}: #{issue.title}"

            if send_to_canny?
              send_to_canny(issue)
            else
              icebox(issue.number, closer)
            end
          end
        end
      end
    end

    def closers
      [
        {
          :search => "repo:#{@repo} is:open created:<#{6.months.ago.to_date.to_s} updated:<#{2.months.ago.to_date.to_s}",
          :message => "This is older than six months and has not been touched in 2 months."
        },
        {
          :search => "repo:#{@repo} is:open updated:<#{2.months.ago.to_date.to_s}",
          :message => "This has not been touched in 2 months."
        }
      ]
    end

    def already_iceboxed?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /Icebox/ }
    end

    def send_to_canny?
      ENV['CANNY_COOKIE'].present?
    end

    def icebox(issue, reason)
      Octokit.add_labels_to_an_issue(@repo, issue, ["Icebox"])
      Octokit.add_comment(@repo, issue, message(reason))
      Octokit.close_issue(@repo, issue)

      puts "Iceboxed #{@repo}/issues/#{issue}!"
    end

    def send_to_canny(issue)
      company_name = ENV['CANNY_COMPANY_NAME']
      board_id = ENV['CANNY_BOARD_ID']
      github_url = "https://github.com/#{@repo}/issues/#{issue.number}"
      canny_url = Iceboxer::Canny.create_issue(issue, github_url, company_name, board_id)
      Octokit.add_labels_to_an_issue(@repo, issue.number, ["Icebox"])
      Octokit.add_comment(@repo, issue.number, canny_message(canny_url))
      Octokit.close_issue(@repo, issue.number)
    end

    def canny_message(url)
      <<-MSG.strip_heredoc
      Hi there! This issue is being closed because it has been inactive for a while.

      But don't worry, it will live on with Canny! Check out its new home: #{url}
      MSG
    end

    def message(reason)
      <<-MSG.strip_heredoc
      ![picture of the iceboxer](https://cloud.githubusercontent.com/assets/699550/5107249/0585a470-6fce-11e4-8190-4413c730e8d8.png)

      #{reason[:message]}

      I am closing this as it is stale.

      I have applied the tag 'Icebox' so you can still see it by querying closed issues.

      Developers: Feel free to reopen if you and your team lead agree it is high priority and will be addressed in the next month.

      MSG
    end
  end
end
