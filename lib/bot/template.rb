require 'octokit'
require 'active_support/all'
require 'uri'

module Bot
  class Template

    def initialize(repo)
      @repo = repo
      @label_bug_report = "Bug Report"
      @label_no_template = "Resolution: No Template"
      @label_stale = "Stale"
      @label_for_discussion = "Type: Discussion"
      @label_core_team = "Core Team"
      @label_customer = "Customer"
      @label_for_stack_overflow = "Resolution: For Stack Overflow"
      @label_ci_test_failure = "❌CI Test Failure"
      @label_feature_request = "Type: Feature Request"
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
          :search => "repo:#{@repo} is:open is:issue -label:\"#{@label_for_discussion}\" -label:\"#{@label_core_team}\" -label:\"#{@label_customer}\" -label:\"#{@label_ci_test_failure}\" -label:\"#{@label_bug_report}\" -label:\"#{@label_docs}\" -label:\"#{@label_for_stack_overflow}\" -label:\"#{@label_good_first_issue}\" -label:\"#{@label_no_template}\" -label:\"#{@label_tests}\" -label:\"#{@label_ci_test_failure}\" created:>=2019-01-26",
          :action => 'close_template'
        },
        {
          :search => "repo:#{@repo} is:open is:issue -label:\"#{@label_core_team}\" -label:\"#{@label_customer}\" label:\"#{@label_no_template}\" created:>=2019-01-26",
          :action => 'close_template'
        }

      ]
    end

    def process(issue, candidate)
      if candidate[:action] == 'close_template'
        close_template(issue)
      end
    end

    def already_nagged?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /issue template/ }
    end

    def close_template(issue)
      labels = [@label_no_template];

      return if issue_contains_label(issue, @label_core_team)
      return if issue_contains_label(issue, @label_customer)

      unless already_nagged?(issue.number)
        Octokit.add_comment(@repo, issue.number, message)
      end

      Octokit.close_issue(@repo, issue.number)
      labels.push @label_ran_commands
      add_labels(issue, labels)
      puts "#{@repo}: ️[TEMPLATE] ❗📋  #{issue.html_url}: #{issue.title} -> Missing template, closed"
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

    def message
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
  end
end
