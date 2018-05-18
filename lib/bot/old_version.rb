require 'octokit'
require 'active_support/all'
require 'uri'

module Bot
  class OldVersion

    def initialize(repo)
      @repo = repo
      @latest_release = Octokit.latest_release(@repo)
      version_info = /v(?<major_minor>[0-9]{1,2}\.[0-9]{1,2})\.(?<patch>[0-9]{1,2})/.match(@latest_release.tag_name)
      @latest_release_version_major_minor = version_info['major_minor']

      @label_needs_more_information = ":grey_question:Needs More Information"
      @label_no_envinfo = ":clipboard:No Environment Info"
      @label_pr_pending = ":clock1:PR Pending"
      @label_old_version = ":rewind:Old Version"
      @label_good_first_issue = "Good first issue"
      @label_core_team = "Core Team"
      @label_for_discussion = "For Discussion"
      @label_stale = "Stale"
    end

    def perform
      Octokit.auto_paginate = true

      # close issues that mention an old version
      candidates.each do |candidate|
        issues = Octokit.search_issues(candidate[:search])
        puts "#{@repo}: [OLD VERSION] Found #{issues.items.count} issues for candidate #{candidate[:action]}..."
        issues.items.each do |issue|
          process(issue, candidate)
        end
      end
    end

    def candidates
      [
        {
          :search => "repo:#{@repo} is:issue is:open \"Environment\" in:body -label:\"#{@label_core_team}\" -label:\"#{@label_for_discussion}\" -label:\"#{@label_old_version}\" -label:\"#{@label_pr_pending}\" -label:\"#{@label_stale}\" created:>#{1.day.ago.to_date.to_s}",
          :action => "nag_old_version"
        },
        {
          :search => "repo:#{@repo} is:issue is:open \"Environment\" in:body -label:\"#{@label_core_team}\" -label:\"#{@label_for_discussion}\" -label:\"#{@label_stale}\" -label:\"#{@label_old_version}\" -label:\"#{@label_pr_pending}\" -label:\"#{@label_good_first_issue}\" created:>#{7.day.ago.to_date.to_s} updated:>#{2.day.ago.to_date.to_s}",
          :action => "nag_old_version"
        },
        {
          :search => "repo:#{@repo} is:issue is:open \"Environment\" in:body label:\"#{@label_no_envinfo}\" -label:\"#{@label_for_discussion}\" -label:\"#{@label_stale}\" -label:\"#{@label_pr_pending}\" -label:\"#{@label_old_version}\" -label:\"#{@label_good_first_issue}\" created:>#{7.day.ago.to_date.to_s} updated:>#{2.day.ago.to_date.to_s}",
          :action => "nag_old_version"
        },
        {
          :search => "repo:#{@repo} is:issue is:open \"Environment\" in:body label:\"#{@label_old_version}\" -label:\"#{@label_stale}\" updated:>#{2.day.ago.to_date.to_s}",
          :action => "remove_label_if_latest_version"
        }
      ]
    end

    def already_nagged_oldversion?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /older version/ }
    end

    def already_nagged_envinfo?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /react-native info/ }
    end

    def strip_comments(text)
      return "" unless text
      regex = /(?=<!--)([\s\S]*?-->)/m
      text.gsub(regex, "")
    end

    def process(issue, candidate)
      puts "#{@repo}: [OLD VERSION] Processing #{issue.html_url}: #{issue.title}"

      if candidate[:action] == 'nag_old_version'
        nag_if_using_old_version(issue, candidate)
      end
      if candidate[:action] == 'remove_label_if_latest_version'
        remove_label_if_latest_version(issue, candidate)
      end

    end

    def nag_if_using_old_version(issue, reason)
      body = strip_comments(issue.body)

      if body =~ /Packages: \(wanted => installed\)/ || body =~ /React Native Environment Info:/
        # Contains envinfo block

        version_info = /(react-native:)\s?[\^~]?(?<requested_version>[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2})\s=>\s(?<installed_version_major_minor>[0-9]{1,2}\.[0-9]{1,2})\.[0-9]{1,2}/.match(body)

        if version_info
          # Check if using latest_version
          if version_info["installed_version_major_minor"] != @latest_release_version_major_minor
            unless already_nagged_oldversion?(issue.number)
              add_labels(issue, [@label_old_version])
              puts "#{@repo}: [OLD VERSION] ❗⏪ #{issue.html_url}: #{issue.title} --> Nagged, wanted #{@latest_release_version_major_minor} got #{version_info["installed_version_major_minor"]}"
            end
          end
        end
      else
        # No envinfo block?
        unless already_nagged_envinfo?(issue.number)
          add_labels(issue, [@label_no_envinfo])
          puts "️#{@repo}: [NO ENV INFO] ❗❔ #{issue.html_url}: #{issue.title} --> Nagged, no envinfo found"
        end
      end
    end

    def remove_label_if_latest_version(issue, reason)
      body = strip_comments(issue.body)

      if body =~ /Packages: \(wanted => installed\)/
        # Contains envinfo block

        version_info = /(react-native:)\s?[\^~]?(?<requested_version>[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2})\s=>\s(?<installed_version_major_minor>[0-9]{1,2}\.[0-9]{1,2})\.[0-9]{1,2}/.match(body)

        if version_info
          # Check if using latest_version
          if version_info["installed_version_major_minor"] == @latest_release_version_major_minor
            puts "#{@repo}: [OLD VERSION] ⏪ #{issue.html_url}: #{issue.title} --> Latest is #{@latest_release_version_major_minor}, got #{version_info["installed_version_major_minor"]}, should remove label."
            remove_label(issue, @label_old_version)
          end
        end
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
        It looks like your issue may refer to an older version of React Native. Can you reproduce the issue on the #{latest_release}?
        MSG
      when "no_envinfo"
        <<-MSG.strip_heredoc
        It looks like your issue may be missing some necessary information. Can you run `react-native info` and edit your issue to include these results under the **Environment** section?
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

    def remove_label(issue, label)
      if issue_contains_label(issue,label)
        puts "#{@repo}: [LABELS] ✂️ #{issue.html_url}: #{issue.title} --> Removing #{label}"
        Octokit.remove_label(@repo, issue.number, label)
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
