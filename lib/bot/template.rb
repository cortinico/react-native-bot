require 'octokit'
require 'active_support/all'
require 'uri'

module Bot
  class Template

    def initialize(repo)
      @repo = repo
      @label_no_template = ":clipboard:No Template"
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
          :search => "repo:#{@repo} is:issue is:open NOT \"Environment\" in:body NOT \"cherry-pick\" in:title -label:\"For Discussion\" -label:\":star2:Feature Request\" -label:\"Core Team\" -label:\":no_entry_sign:Docs\" -label:\":no_entry_sign:For Stack Overflow\" -label:\"Good first issue\" -label:\":clipboard:No Template\" -label:\":nut_and_bolt:Tests\" created:>=2018-03-19",
          :action => 'nag_template'
        },
        {
          :search => "repo:#{@repo} is:issue is:open \"Environment\" in:body label:\":clipboard:No Template\" created:>=2018-03-19 updated:>=#{3.day.ago.to_date.to_s}",
          :action => 'remove_label'
        }
      ]
    end

    def process(issue, candidate)
      puts "#{@repo}: [TEMPLATE] Processing #{issue.html_url}: #{issue.title}"

      if candidate[:action] == 'nag_template'
        nag_template(issue)
      end
      if candidate[:action] == 'remove_template_label'
        remove_template_label(issue)
      end
    end

    def already_nagged?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /Issue Template/ }
    end

    def nag_template(issue)
      labels = [@label_no_template];

      unless already_nagged?(issue.number)
        Octokit.add_comment(@repo, issue.number, message)
        puts "#{@repo}: ️[TEMPLATE] ❗📋  #{issue.html_url}: #{issue.title} -> Missing template, nagged"
      end

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
      It looks like your issue may be incomplete. Are all the fields required by the [Issue Template](https://raw.githubusercontent.com/facebook/react-native/master/.github/ISSUE_TEMPLATE.md) filled out?

      If you believe your issue contains all the relevant information, let us know in order to have a maintainer remove the ":clipboard:No Template" label.
      MSG
    end
  end
end
