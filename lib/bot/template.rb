require 'octokit'
require 'active_support/all'
require 'uri'

module Bot
  class Template

    def initialize(repo)
      @repo = repo
      @label_no_template = ":clipboard:No Template"
      @label_stale = "Stale"
      @label_for_discussion = "For Discussion"
      @label_core_team = "Core Team"
      @label_for_stack_overflow = ":no_entry_sign:For Stack Overflow"
    end

    def perform
      Octokit.auto_paginate = true

      candidates.each do |candidate|
        issues = Octokit.search_issues(candidate[:search])
        puts "#{@repo}: [TEMPLATE] Found #{issues.items.count} issues for candidate #{candidate[:action]}..."
        issues.items.each do |issue|
          process(issue, candidate)
        end
      end
    end

    def candidates
      [
        {
          :search => "repo:#{@repo} is:issue is:open \"For Discussion\" in:body -label:\"#{@label_for_discussion}\"created:>=2018-05-29",
          :action => 'label_for_discussion'
        },
        {
          :search => "repo:#{@repo} is:issue is:open NOT \"Environment\" NOT \"For Discussion\" in:body NOT \"cherry-pick\" in:title -label:\"#{@label_for_discussion}\" -label:\"#{@label_stale}\" -label:\":star2:Feature Request\" -label:\"Core Team\" -label:\":no_entry_sign:Docs\" -label:\"#{@label_for_stack_overflow}\" -label:\"Good first issue\" -label:\"#{@label_no_template}\" -label:\":nut_and_bolt:Tests\" created:>=2018-06-14",
          :action => 'close_template'
        },
        {
          :search => "repo:#{@repo} is:issue is:open \"Click \\\"Preview\\\" for a nicer view!\" in:body -label:\"#{@label_stale}\" -label:\"#{@label_for_stack_overflow}\" created:>=#{1.day.ago.to_date.to_s}",
          :action => 'close_question'
        }
      ]
    end

    def process(issue, candidate)
      puts "#{@repo}: [TEMPLATE] Processing #{issue.html_url}: #{issue.title}"

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

      If you'd like to start a discussion, check out https://discuss.reactjs.org or follow the [discussion template](https://github.com/facebook/react-native/issues/new?template=discussion.md).
      MSG
    end
  end
end
