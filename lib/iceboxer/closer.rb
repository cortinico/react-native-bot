require 'octokit'
require 'active_support/all'

module Iceboxer
  class Closer

    def initialize(repo)
      @repo = repo
    end

    def perform
      closers.each do |closer|
        issues = Octokit.search_issues(closer[:search])
        puts "#{@repo}: [CLOSERS] [#{closer[:close_reason]}] Found #{issues.items.count} issues..."
        issues.items.each do |issue|
          nag(issue, closer)
        end
      end
    end

    def closers
      [
        {
          :search => "repo:#{@repo} is:issue is:open label:\":no_entry_sign:For Stack Overflow\" created:>=#{1.week.ago.to_date.to_s}",
          :message => "Please use [Stack Overflow](http://stackoverflow.com/questions/tagged/react-native) for this type of question.",
          :close_reason => "For Stack Overflow"
        },
        {
          :search => "repo:#{@repo} is:issue is:open label:\":clipboard:No Template\" -label:\"Core Team\" -label:\"For Discussion\" updated:<#{7.days.ago.to_date.to_s}",
          :message => "This issue was marked as lacking information required by the issue template. There has been no activity on this issue for a while, so I will go ahead and close it.\n\nIf you found this thread after encountering the same issue in the [latest release](https://github.com/facebook/react-native/releases), please feel free to create a new issue with up-to-date information by clicking [here](https://github.com/facebook/react-native/issues/new).\n\nIf you are the author of this issue and you believe this issue was closed in error (i.e. you have edited your issue to ensure it meets the template requirements), please let us know.",
          :close_reason => "Missing information, issue not updated in last seven days"
        },
        {
          :search => "repo:#{@repo} is:issue is:open  label:\":no_entry_sign:Invalid\" updated:>=#{1.week.ago.to_date.to_s}",
          :message => "We use GitHub Issues exclusively for tracking bugs in React Native. See the [React Native Community Support page](http://facebook.github.io/react-native/help.html) for a list of places where you may ask for help.",
          :close_reason => "Issue does not belong here."
        }
      ]
    end

    def nag(issue, reason)
      add_labels(issue, ["Ran Commands"])
      Octokit.add_comment(@repo, issue.number, reason[:message])
      Octokit.close_issue(@repo, issue.number)

      puts "#{@repo}: [CLOSERS] 🚫 #{issue.html_url}: #{issue.title} --> #{reason[:close_reason]}"
    end

    def message(reason)
      <<-MSG.strip_heredoc
      <!--
        {
          "closed_by":"react-native-bot",
          "close_reason": "#{reason[:close_reason]}"
        }
      -->
      #{reason[:message]}
      MSG
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
