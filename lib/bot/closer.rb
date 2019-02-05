require 'octokit'
require 'active_support/all'

module Bot
  class Closer

    def initialize(repo)
      @repo = repo
      @label_old_version = "Resolution: Old Version"
      @label_for_stack_overflow = "Resolution: For Stack Overflow"
      @label_question = "Question"
      @label_type_question = "Type: Question"
      @label_no_template = "Resolution: No Template"
      @label_no_envinfo = "Resolution: Missing Environment Info"
      @label_for_discussion = "Type: Discussion"
      @label_help_wanted = "Help Wanted :octocat:"
      @label_good_first_issue = "Good first issue"
      @label_core_team = "Core Team"
      @label_customer = "Customer"
      @label_invalid = "Type: Invalid"
      @label_pr_pending = "Resolution: PR Submitted"
    end

    def perform
      candidates.each do |candidate|
        issues = Octokit.search_issues(candidate[:search], { :per_page => 100 })
        issues.items.each do |issue|
          nag(issue, candidate)
        end
      end
    end

    def candidates
      [
        {
          :search => "repo:#{@repo} is:issue is:open label:\"#{@label_question}\"",
          :message => "We are using GitHub issues exclusively to track bugs in React Native. GitHub may not be the ideal place to ask a question, but you can try asking over on [Stack Overflow](http://stackoverflow.com/questions/tagged/react-native), or on [Reactiflux](https://www.reactiflux.com/). You may also use [discuss.reactjs.org/](https://discuss.reactjs.org/) to discuss best practices.",
          :close_reason => "Issue is a Question"
        },
        {
          :search => "repo:#{@repo} is:issue is:open label:\"#{@label_type_question}\"",
          :message => "We are using GitHub issues exclusively to track bugs in React Native. GitHub may not be the ideal place to ask a question, but you can try asking over on [Stack Overflow](http://stackoverflow.com/questions/tagged/react-native), or on [Reactiflux](https://www.reactiflux.com/). You may also use [discuss.reactjs.org/](https://discuss.reactjs.org/) to discuss best practices.",
          :close_reason => "Issue is a Question"
        },
        {
          :search => "repo:#{@repo} is:issue is:open label:\"#{@label_for_stack_overflow}\"",
          :message => "Please use [Stack Overflow](http://stackoverflow.com/questions/tagged/react-native) for this type of question.",
          :close_reason => "For Stack Overflow"
        },
        {
          :search => "repo:#{@repo} is:issue is:open label:\"#{@label_invalid}\" updated:>=#{1.week.ago.to_date.to_s}",
          :message => "We use GitHub Issues exclusively for tracking bugs in React Native. See the [React Native Community Support page](http://facebook.github.io/react-native/help.html) for a list of places where you may ask for help.",
          :close_reason => "Issue does not belong here."
        },
        {
          :search => "repo:#{@repo} is:issue is:open label:\"#{@label_old_version}\" -label:\"#{@label_core_team}\" -label:\"#{@label_customer}\" -label:\"#{@label_for_discussion}\" -label:\"#{@label_pr_pending}\" comments:<5 updated:<#{14.days.ago.to_date.to_s}",
          :message => "I am closing this issue because it does not appear to have been verified on the latest release, and there has been no followup in a while.\n\nIf you found this thread after encountering the same issue in the [latest release](https://github.com/facebook/react-native/releases), please feel free to create a new issue with up-to-date information by clicking [here](https://github.com/facebook/react-native/issues/new).",
          :close_reason => "Old version, issue not updated in last fourteen days"
        },
        {
          :search => "repo:#{@repo} is:issue is:open label:\"#{@label_no_envinfo}\" -label:\"#{@label_core_team}\" -label:\"#{@label_customer}\" -label:\"#{@label_for_discussion}\" -label:\"#{@label_pr_pending}\" updated:<#{7.days.ago.to_date.to_s}",
          :message => "I am closing this issue because it does not contain the necessary environment info, and there has been no followup in a while.\n\nIf you found this thread after encountering the same issue in the [latest release](https://github.com/facebook/react-native/releases), please feel free to create a new issue with up-to-date information by clicking [here](https://github.com/facebook/react-native/issues/new).",
          :close_reason => "No environment info, issue not updated in last seven days"
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
