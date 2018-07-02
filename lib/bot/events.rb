require 'octokit'
require 'active_support/all'

module Bot
  class Events

    def initialize(repo)
      @repo = repo
    end

    def perform
      events = Octokit.user_public_events("facebook-github-bot")
      puts "#{@repo}: [EVENTS] Found #{events.count} events..."
      events.each do |event|
        if event.payload && event.payload.commits
          event.payload.commits.each do |commit|
            if commit.sha && is_pullrequest_closing_commit(commit)
              pr_number = closed_pullrequest(commit)
              unless already_nagged_closing_commit?(pr_number)
                puts "Commit #{commit.sha} potentially closed #{pr_number}"

                full_commit = Octokit.commit(@repo, commit.sha)

                commit_author = "@facebook-github-bot"

                if commit.author && commit.author.name
                  commit_author = commit.author.name
                end
                if full_commit && full_commit.author && full_commit.author.login
                  commit_author = "@#{full_commit.author.login}"
                end
                Octokit.add_comment(@repo, pr_number, "This pull request was closed by #{commit_author} in #{commit.sha}.\n\nOnce this commit is added to a release, you will see the corresponding version tag below the description at #{commit.sha}. If the commit has a single `master` tag, [it is not yet part of a release](https://github.com/react-native-community/react-native-releases#when-will-my-fix-make-it-into-a-release).")
                Octokit.lock_issue(@repo, pr_number, { :lock_reason => "resolved", :accept => "application/vnd.github.sailor-v-preview+json" })
                Octokit.add_labels_to_an_issue(@repo, pr_number, ["Merged"])
              end
            end
          end
        end
      end
    end

    def is_pullrequest_closing_commit(commit)
      commit.message =~ /Closes https:\/\/github.com\/facebook\/react-native\/pull\/[0-9]+/
    end

    def closed_pullrequest(commit)
      commit.message =~ /Closes https:\/\/github.com\/facebook\/react-native\/pull\/([0-9]+)/
      $1
    end

    def already_nagged_closing_commit?(pr_number)
      comments = Octokit.issue_comments(@repo, pr_number)
      comments.any? { |c| c.user.login == "react-native-bot" && c.body =~ /This pull request was closed by/ }
    end

  end
end
