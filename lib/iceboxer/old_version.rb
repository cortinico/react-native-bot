require 'octokit'
require 'active_support/all'
require 'uri'

module Iceboxer
  class OldVersion

    def initialize(repo)
      @repo = repo
      @latest_release = Octokit.latest_release(@repo)
      version_info = /v(?<major_minor>[0-9]{1,2}\.[0-9]{1,2})\.(?<patch>[0-9]{1,2})/.match(@latest_release.tag_name)
      @latest_release_version_major_minor = version_info['major_minor']
    end

    def perform
      Octokit.auto_paginate = true

      # close issues that mention an old version
      closers.each do |closer|
        issues = Octokit.search_issues(closer[:search])
        puts "[OLD VERSION] Found #{issues.items.count} issues to nag in #{@repo} ..."
        issues.items.each do |issue|
          unless already_nagged?(issue.number)
            nag_if_using_old_version(issue, closer)
          end
        end
      end
    end

    def closers
      [
        {
          :search => "repo:#{@repo} is:issue is:open \"Environment\" in:body -label:\"Core Team\" -label:\"Old Version :rewind:\" created:>#{1.day.ago.to_date.to_s}"
        }
      ]
    end

    def already_nagged?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /older version/ } or comments.any? { |c| c.body =~ /react-native info/ }
    end

    def strip_comments(text)
      regex = /(?=<!--)([\s\S]*?-->)/m
      text.gsub(regex, "")
    end

    def nag_if_using_old_version(issue, reason)
      body = strip_comments(issue.body)

      if body =~ /Packages: \(wanted => installed\)/
        # Contains envinfo block

        version_info = /(react-native:)\s?(?<requested_version>[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2})\s=>\s(?<installed_version_major_minor>[0-9]{1,2}\.[0-9]{1,2})\.[0-9]{1,2}/.match(body)

        if version_info
          # Check if using latest_version
          if version_info["installed_version_major_minor"] != @latest_release_version_major_minor
            label_old_version = "Old Version :rewind:"
            Octokit.add_comment(@repo, issue.number, message("old_version"))
            Octokit.add_labels_to_an_issue(@repo, issue.number, [label_old_version, "Ran Commands"]) unless issue.labels.include?(label_old_version)
      
            puts "[OLD VERSION] Nagged #{issue.html_url} --> wanted #{@latest_release_version_major_minor} got #{version_info["installed_version_major_minor"]}"
          end
        end
      else
        # No envinfo block?
        label_needs_more_information = "Needs More Information :grey_question:"
        Octokit.add_comment(@repo, issue.number, message("no_envinfo"))
        Octokit.add_labels_to_an_issue(@repo, issue.number, [label_needs_more_information, "Ran Commands"]) unless issue.labels.include?(label_needs_more_information)
        puts "[OLD VERSION] Nagged #{issue.html_url} --> No envinfo found"
      end
    end

    def latest_release
      if @latest_release_version_major_minor
        "[latest release, v#{@latest_release_version_major_minor}](#{@latest_release.html_url})"
      else
        "[latest release](https://github.com/facebook/react-native/releases)"
      end
    end

    def message(reason)
      case reason
      when "old_version"
        <<-MSG.strip_heredoc
        Thanks for posting this! It looks like your issue may refer to an older version of React Native. Can you reproduce the issue on the #{latest_release}?
        
        Thank you for your contributions.
        MSG
      when "no_envinfo"
        <<-MSG.strip_heredoc
        Thanks for posting this! It looks like your issue may be missing some necessary information. Can you run `react-native info` and edit your issue to include these results under the **Environment** section?
        
        Thank you for your contributions.
        MSG
      end
    end
  end
end
