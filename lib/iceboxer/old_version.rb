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
        puts "#{@repo}: [OLD VERSION] Found #{issues.items.count} issues..."
        issues.items.each do |issue|
          unless already_nagged?(issue.number)
            puts "#{@repo}: [OLD VERSION] Processing #{issue.html_url}: #{issue.title}"
            nag_if_using_old_version(issue, closer)
          end
        end
      end
    end

    def closers
      [
        {
          :search => "repo:#{@repo} is:issue is:open \"Environment\" in:body -label:\"Core Team\" -label:\":rewind:Old Version\" created:>#{1.day.ago.to_date.to_s}"
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
            label_old_version = ":rewind:Old Version"
            Octokit.add_comment(@repo, issue.number, message("old_version"))
            add_labels(issue, [label_old_version])
      
            puts "#{@repo}: [OLD VERSION] ❗⏪ #{issue.html_url}: #{issue.title} --> Nagged, wanted #{@latest_release_version_major_minor} got #{version_info["installed_version_major_minor"]}"
          end
        end
      else
        # No envinfo block?
        label_needs_more_information = ":grey_question:Needs More Information"
        Octokit.add_comment(@repo, issue.number, message("no_envinfo"))
        add_labels(issue, [label_needs_more_information])
        puts "️#{@repo}: [NO ENV INFO] ❗❔ #{issue.html_url}: #{issue.title} --> Nagged, no envinfo found"
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

    def add_labels(issue, labels)
      new_labels = []

      labels.each do |label|
        new_labels.push label unless issue_contains_label(issue, label)
      end

      if new_labels.count > 0
        puts "#{@repo}: [LABELS] 📍 #{issue.html_url}: #{issue.title} --> Adding #{new_labels}"
        Octokit.add_labels_to_an_issue(@repo, issue.number, new_labels)
      end
    end

    def issue_contains_label(issue, label)
      existing_labels = []

      issue.labels.each do |issue_label| 
        existing_labels.push issue_label.name if issue_label.name
      end

      existing_labels.include? label
    end   
  end
end
