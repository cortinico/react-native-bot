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
      @label_needs_issue_template = "Needs: Issue Template"
      @label_needs_author_feedback = "Needs: Author Feedback"
      @label_resolution_needs_more_information = "Resolution: Needs More Information"
      @label_needs_triage = "Needs: Triage"
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
          :search => "repo:#{@repo} is:open is:issue -label:\"#{@label_for_discussion}\" -label:\"#{@label_core_team}\" -label:\"#{@label_rn_team}\" -label:\"#{@label_contributor}\" -label:\"#{@label_customer}\" -label:\"#{@label_partner}\" -label:\"#{@label_ci_test_failure}\" -label:\"#{@label_bug_report}\" -label:\"#{@label_bug_report_alt}\" -label:\"#{@label_type_bug_report}\" -label:\"#{@label_docs}\" -label:\"#{@label_for_stack_overflow}\" -label:\"#{@label_good_first_issue}\" -label:\"#{@label_resolution_no_template} -label:\"#{@label_needs_issue_template}\" -label:\"#{@label_tests}\" -label:\"#{@label_ci_test_failure}\" created:>=2020-01-17",
          :action => 'close_template'
        },
        {
          :search => "repo:#{@repo} is:open is:issue -label:\"#{@label_core_team}\" -label:\"#{@label_rn_team}\" -label:\"#{@label_contributor}\" -label:\"#{@label_customer}\" -label:\"#{@label_partner}\" -label:\"#{@label_needs_author_feedback}\" -label:\"#{@label_resolution_needs_more_information}\" label:\"#{@label_bug_report}\" NOT \"React Native version\" in:body created:>=2019-05-08",
          :action => 'nag_template'
        }
      ]
    end

    def process(issue, candidate)
      if candidate[:action] == 'close_template'
        close_template(issue)
      end
      if candidate[:action] == 'nag_template'
        nag_template(issue)
      end
    end

    def already_nagged?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /issue template/ }
    end

    def contains_envinfo?(issue)
      body = strip_comments(issue.body)
      body =~ /Packages: \(wanted => installed\)/ || body =~ /React Native Environment Info:/ || body =~ /Environment:/ || body =~ /React Native version:/
    end

    def strip_comments(text)
      return "" unless text
      regex = /(?=<!--)([\s\S]*?-->)/m
      text.gsub(regex, "")
    end

    def close_template(issue)
      labels = [@label_needs_issue_template];

      return if issue_contains_label(issue, @label_core_team)
      return if issue_contains_label(issue, @label_rn_team)
      return if issue_contains_label(issue, @label_contributor)
      return if issue_contains_label(issue, @label_customer)
      return if issue_contains_label(issue, @label_partner)

      unless already_nagged?(issue.number)
        Octokit.add_comment(@repo, issue.number, close_message)
      end

      Octokit.close_issue(@repo, issue.number)
      add_labels(issue, labels)
      puts "#{@repo}: ️[TEMPLATE] ❗📋  #{issue.html_url}: #{issue.title} -> Missing template, closed"
    end

    def nag_template(issue)
      labels = [@label_needs_issue_template];

      return if contains_envinfo?(issue)
      return if issue_contains_label(issue, @label_core_team)
      return if issue_contains_label(issue, @label_rn_team)
      return if issue_contains_label(issue, @label_contributor)
      return if issue_contains_label(issue, @label_customer)
      return if issue_contains_label(issue, @label_partner)
      return if already_nagged?(issue.number)

      Octokit.add_comment(@repo, issue.number, nag_message)
      add_labels(issue, labels)
      puts "#{@repo}: ️[TEMPLATE] ❗📋  #{issue.html_url}: #{issue.title} -> Incomplete template, nagged"
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

    def close_message
      <<-MSG.strip_heredoc
      <!--
        {
          "flagged_by":"react-native-bot",
          "nag_reason": "no-template"
        }
      -->
      We are automatically closing this issue because it does not appear to follow any of the provided [issue templates](https://github.com/facebook/react-native/issues/new/choose).

      👉 [Click here if you want to report a reproducible bug or regression in React Native.](https://github.com/facebook/react-native/issues/new?template=bug_report.md)
      MSG
    end

    def nag_message
      <<-MSG.strip_heredoc
      <!--
        {
          "flagged_by":"react-native-bot",
          "nag_reason": "incomplete-template"
        }
      -->
      Thanks for submitting your issue. Can you take another look at your description and make sure the issue template has been filled in its entirety?

      👉 [Click here if you want to take another look at the Bug Report issue template.](https://github.com/facebook/react-native/issues/new?template=bug_report.md)
      MSG
    end

  end
end
