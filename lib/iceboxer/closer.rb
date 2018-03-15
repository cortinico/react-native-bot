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
        puts "[CLOSERS] Found #{issues.items.count} issues to close in #{@repo} ..."
        issues.items.each do |issue|
          unless already_nagged?(issue.number)
            puts "Closing #{@repo}/issues/#{issue.number}: #{issue.title}"
            nag(issue.number, closer)
          end
        end
      end
    end

    def closers
      [
        {
          :search => "repo:#{@repo} is:issue is:open label:\"For Stack Overflow :question:\" created:>2018-03-12",
          :message => "This issue looks like a question that would be best asked on [Stack Overflow](http://stackoverflow.com/questions/tagged/react-native).\n\nStack Overflow is amazing for Q&A: it has a reputation system, voting, the ability to mark a question as answered. Because of the reputation system it is likely the community will see and answer your question there. This also helps us use the GitHub bug tracker for bugs only.\n\nWill close this as this is really a question that should be asked on Stack Overflow."
        },
        {
          :search => "repo:#{@repo} is:issue is:open label:\"No Template :clipboard:\" -label:\"Core Team\" -label:\"For Discussion\" updated:<#{7.days.ago.to_date.to_s}",
          :message => "This issue was marked as lacking information required by the issue template. There has been no activity on this issue for a while, so I will go ahead and close it.\n\nIf you found this thread after encountering the same issue in the [latest release](https://github.com/facebook/react-native/releases), please feel free to create a new issue with up-to-date information by clicking [here](https://github.com/facebook/react-native/issues/new).\n\nIf you are the author of this issue and you believe this issue was closed in error (i.e. you have edited your issue to ensure it meets the template requirements), please let us know."
        }        
      ]
    end

    def already_nagged?(issue)
      comments = Octokit.issue_comments(@repo, issue)
      comments.any? { |c| c.body =~ /Stack Overflow/ }
    end

    def nag(issue, reason)
      Octokit.add_labels_to_an_issue(@repo, issue, ["Ran Commands"])
      Octokit.add_comment(@repo, issue, reason[:message])
      Octokit.close_issue(@repo, issue)

      puts "Closed #{@repo}/issues/#{issue}!"
    end

    def message(reason)
      <<-MSG.strip_heredoc
      #{reason[:message]}
      MSG
    end
  end
end