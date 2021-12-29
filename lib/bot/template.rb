require 'octokit'
require 'active_support/all'
require 'uri'

module Bot
  class Template

    def initialize(repo)
      @repo = repo
      @label_bug_report_alt = "Bug Report"
      @label_bug_report = "Bug"
      @label_type_bug_report = "Type: Bug Report"
      @label_resolution_no_template = "Resolution: No Template"
      @label_needs_environment_info = "Needs: Environment Info"
      @label_needs_author_feedback = "Needs: Author Feedback"
      @label_needs_triage = "Needs: Triage :mag:"
      @label_resolution_needs_more_information = "Resolution: Needs More Information"
      @label_stale = "Stale"
      @label_for_discussion = "Type: Discussion"
      @label_core_team = "Core Team"
      @label_rn_team = "RN Team"
      @label_contributor = "Contributor"
      @label_customer = "Customer"
      @label_partner = "Partner"
      @label_for_stack_overflow = "Resolution: For Stack Overflow"
      @label_ci_test_failure = "❌CI Test Failure"
      @label_feature_request = "Type: Enhancement"
      @label_docs = "Type: Docs"
      @label_good_first_issue = "Good first issue"
      @label_tests = "🔩Test Infrastructure"
      @label_ran_commands = "Ran Commands"
    end

    def perform
      Octokit.auto_paginate = true

      candidates.each do |candidate|
        issues = Octokit.search_issues(candidate[:search], { :per_page => 100 })
        issues.items.each do |issue|
          process(issue, candidate)
        end
      end
    end

    def candidates
      [
        {
          :search => "repo:#{@repo} is:open is:issue -label:\"#{@label_core_team}\" -label:\"#{@label_rn_team}\" -label:\"#{@label_contributor}\" -label:\"#{@label_customer}\" -label:\"#{@label_partner}\" -label:\"#{@label_needs_environment_info}\" label:\"#{@label_needs_triage}\" created:>=#{2.hour.ago.to_date.to_s}",
          :action => 'nag_template_envinfo'
        },
        {
          :search => "repo:#{@repo} is:open is:issue label:\"#{@label_needs_environment_info}\" updated:>=#{2.hour.ago.to_date.to_s}",
          :action => 'verify_if_envinfo_added'
        }

      ]
    end

    def process(issue, candidate)
      if candidate[:action] == 'nag_template_envinfo'
        nag_template_envinfo(issue)
      end
      if candidate[:action] == 'verify_if_envinfo_added'
        verify_if_envinfo_added(issue)
      end
    end

    def already_nagged?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /issue template/ }
    end

    def contains_envinfo?(issue)
      body = strip_comments(issue.body)
      body =~ /Packages: \(wanted => installed\)/ || body =~ /React Native Environment Info:/ || body =~ /Environment:/ || body =~ /React Native version:/ || body =~ /Output of `react-native info`/ || body =~ /Output of `npx react-native info`/
    end

    def strip_comments(text)
      return "" unless text
      regex = /(?=<!--)([\s\S]*?-->)/m
      text.gsub(regex, "")
    end

    def nag_template_envinfo(issue)
      return if contains_envinfo?(issue)
      # add_nag_comment(issue, nag_message)
      add_labels(issue, [@label_needs_environment_info, @label_needs_author_feedback])
      remove_label(issue, @label_needs_triage)
    end

    def verify_if_envinfo_added(issue)
      remove_label(issue, @label_needs_environment_info) if contains_envinfo?(issue)
    end

    def add_nag_comment(issue, message)
      return if issue_contains_label(issue, @label_core_team)
      return if issue_contains_label(issue, @label_rn_team)
      return if issue_contains_label(issue, @label_contributor)
      return if issue_contains_label(issue, @label_customer)
      return if issue_contains_label(issue, @label_partner)
      return if already_nagged?(issue.number)

      Octokit.add_comment(@repo, issue.number, message)
      puts "#{@repo}: ️[TEMPLATE] ❗📋  #{issue.html_url}: #{issue.title}"
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

    def nag_message
      <<-MSG.strip_heredoc
      <!--
        {
          "flagged_by":"react-native-bot",
          "nag_reason": "incomplete-template"
        }
      -->
      Thanks for submitting your issue. Please run `react-native info` in your terminal and copy the results into your issue description after "React Native version:". If you have already done this, please disregard this message.

      👉 [Click here if you want to take another look at the Bug Report issue template.](https://github.com/facebook/react-native/issues/new?template=bug_report.md)
      MSG
    end

  end
end
