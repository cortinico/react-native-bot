require 'octokit'
require 'active_support/all'

module Bot
  class Events

    def initialize(repo)
      @repo = repo
      @label_pr_merged = "Merged"
      @label_import_started = "Import Started"
      @label_import_failed = "Import Failed"
      @label_pr_blocked_on_fb = "Blocked on FB"
      @label_pr_needs_review = "Internal Diff Needs Review"
      @label_pr_needs_love = "Internal Diff Needs FB Love"
    end

    def perform
      events = Octokit.user_public_events("facebook-github-bot")
      events.each do |event|
        if event.payload && event.payload.commits
          event.payload.commits.each do |commit|
            if commit.sha && is_pullrequest_closing_commit(commit)
              pr_number = closed_pullrequest(commit)
              if already_nagged_closing_commit?(pr_number, commit)
                puts "Skipping #{commit.sha}, which closed #{pr_number}, as we already processed it"
              elsif already_labeled_merged?(pr_number)
                puts "Skipping #{commit.sha}, which closed #{pr_number}, as we already processed it (Merged label)"
              else
                puts "Commit #{commit.sha} potentially closed #{pr_number}"
                full_commit = Octokit.commit(@repo, commit.sha)

                commit_author = "@facebook-github-bot"

                if commit.author && commit.author.name
                  commit_author = commit.author.name
                end
                if full_commit && full_commit.author && full_commit.author.login
                  commit_author = "@#{full_commit.author.login}"
                end

                unless ENV['READ_ONLY'].present?
                  Octokit.add_comment(@repo, pr_number, "This pull request was successfully merged by #{commit_author} in **#{commit.sha}**.\n\n<sup>[When will my fix make it into a release?](https://github.com/react-native-community/react-native-releases#when-will-my-fix-make-it-into-a-release) | [Upcoming Releases](https://github.com/react-native-community/react-native-releases/issues)</sup>")
                  Octokit.add_labels_to_an_issue(@repo, pr_number, [@label_pr_merged])
                  # Octokit.lock_issue(@repo, pr_number, { :lock_reason => "resolved", :accept => "application/vnd.github.sailor-v-preview+json" })
                end
              end
            end
          end
        end
      end
    end

    def is_pullrequest_closing_commit(commit)
      commit.message =~ /Closes https:\/\/github.com\/facebook\/react-native\/pull\/([0-9]+)|Pull Request resolved: https:\/\/github.com\/facebook\/react-native\/pull\/([0-9]+)/
    end

    def closed_pullrequest(commit)
      pr_number = nil
      commit.message =~ /Closes https:\/\/github.com\/facebook\/react-native\/pull\/([0-9]+)|Pull Request resolved: https:\/\/github.com\/facebook\/react-native\/pull\/([0-9]+)/
      pr_number = $1 if $1
      pr_number = $2 if $2
      pr_number
    end

    def already_labeled_merged?(pr_number)
      labels_for_issue(pr_number).each do |label|
        if label.name == @label_pr_merged
          return true
        end
      end

      return false
    end

    def already_nagged_closing_commit?(pr_number, commit)
      comments = Octokit.issue_comments(@repo, pr_number)
      comments.any? { |c| c.user.login == "react-native-bot" && (c.body.include?("merged commit") || c.body.include?("pull requested was closed by") || c.body.include?("pull requested was successfully merged") ) }
    end

    def labels_for_issue(issue_number)
      existing_labels = Octokit.labels_for_issue(@repo, issue_number)
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
