require 'octokit'
require 'active_support/all'
require 'uri'

module Bot
  class Template

    def initialize(repo)
      @repo = repo
      @label_bug_report = "Bug Report"
      @label_no_template = "📋No Template"
      @label_stale = "Stale"
      @label_for_discussion = "Type: Discussion"
      @label_core_team = "Core Team"
      @label_for_stack_overflow = "Resolution: For Stack Overflow"
      @label_ci_test_failure = "❌CI Test Failure"
      @label_feature_request = "Type: Feature Request"
      @label_docs = "Type: Docs"
      @label_good_first_issue = "Good first issue"
      @label_tests = "🔩Test Infrastructure"
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
          :search => "repo:#{@repo} is:open is:issue -label:\"#{@label_for_discussion}\" -label:\"#{@label_core_team}\" -label:\"#{@label_ci_test_failure}\" -label:\"#{@label_bug_report}\" -label:\"#{@label_docs}\" -label:\"#{@label_for_stack_overflow}\" -label:\"#{@label_good_first_issue}\" -label:\"#{@label_no_template}\" -label:\"#{@label_tests}\" -label:\"#{@label_ci_test_failure}\" created:>=2019-01-26",
          :action => 'close_template'
        }
      ]
    end

    def process(issue, candidate)
      if candidate[:action] == 'label_for_discussion'
        label_for_discussion(issue)
      end
      if candidate[:action] == 'close_template'
        close_template(issue)
      end
      if candidate[:action] == 'remove_template_label'
        remove_template_label(issue)
      end
      if candidate[:action] == 'close_question'
        close_question(issue)
      end
    end

    def already_nagged?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /Issue Template/ }
    end

    def label_for_discussion(issue)
      labels = [@label_for_discussion];
      add_labels(issue, labels)
    end

    def close_template(issue)
      labels = [@label_no_template];

      return if issue_contains_label(issue, @label_for_discussion)
      return if issue_contains_label(issue, @label_core_team)

      unless already_nagged?(issue.number)
        Octokit.add_comment(@repo, issue.number, message)
      end

      Octokit.close_issue(@repo, issue.number)
      add_labels(issue, ["Ran Commands"])
      puts "#{@repo}: ️[TEMPLATE] ❗📋  #{issue.html_url}: #{issue.title} -> Missing template, closed"

      add_labels(issue, labels)
    end

    def close_question(issue)
      labels = [@label_for_stack_overflow];
      add_labels(issue, labels)
    end

    def remove_template_label(issue)
      remove_label(issue, @label_no_template)
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

      Please make use of the [bug report template](https://github.com/facebook/react-native/issues/new?template=bug_report.md) to let us know about a **reproducible bug or regression** in the **core** React Native library.

      If you'd like to propose a change or discuss a feature request, there is a repository dedicated to [Discussions and Proposals](https://github.com/react-native-community/discussions-and-proposals) you may use for this purpose.
      MSG
    end
  end
end
