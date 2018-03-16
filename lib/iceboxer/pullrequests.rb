require 'octokit'
require 'active_support/all'

module Iceboxer
  class PullRequests

    def initialize(repo)
      @repo = repo
      @core_contributors = [
        "anp",
        "ide",
        "shergin",
        "brentvatne",
        "charpeni",
        "dlowder-salesforce",
        "grabbou",
        "keltset",
        "lelandrichardson",
        "skevy",
        "rozele",
        "satya164",
        "janicduplessis",
        "matthargett",
        "hramos"
      ]
    end

    def perform
      candidates.each do |candidate|
        prs = Octokit.search_issues(candidate[:search])
        puts "[PR] Found #{prs.items.count} new PRs to process in #{@repo} ..."
        prs.items.each do |pr|
          puts "Processing #{pr.html_url}: #{pr.title}"
          process(pr, candidate)
        end
      end
    end

    def candidates
      [
        {
          :search => "repo:#{@repo} is:pr is:open created:>#{1.day.ago.to_date.to_s}",
          :action => 'lint_pr'
        },
        {
          :search => "repo:#{@repo} is:open is:pr -label:\"Release Notes :clipboard:\" -label:\"No Release Notes :clipboard:\" created:>#{1.day.ago.to_date.to_s}",
          :action => 'check_release_notes'
        },
        {
          :search => "repo:#{@repo} is:open is:pr label:\"No Release Notes :clipboard:\" updated:>#{1.day.ago.to_date.to_s}",
          :action => 'check_release_notes'
        }                
      ]
    end

    def strip_comments(text)
      regex = /(?=<!--)([\s\S]*?-->)/m
      text.gsub(regex, "")
    end

    def process(pr, candidate)
      if candidate[:action] == 'check_release_notes'
        check_release_notes(pr)
      end
      if candidate[:action] == 'check_core_team'
        check_core_team(pr)
      end
      if candidate[:action] == 'lint_pr'
        lint_pr(pr)
      end
    end

    def check_release_notes(pr)
      label_release_notes = "Release Notes :clipboard:"
      label_no_release_notes = "No Release Notes :clipboard:"

      releaseNotesRegex = /\[\s?(?<platform>ANDROID|CLI|DOCS|GENERAL|INTERNAL|IOS|TVOS|WINDOWS)\s?\]\s*?\[\s?(?<category>BREAKING|BUGFIX|ENHANCEMENT|FEATURE|MINOR)\s?\]\s*?\[(.*)\]\s*?\-\s*?(.*)/

      body = strip_comments(pr.body)
      releaseNotesCaptureGroups = releaseNotesRegex.match(body)
      labels = ["Ran Commands"]
      if releaseNotesCaptureGroups

        labels.push label_release_notes unless pr.labels.include?(label_release_notes)

        platform = releaseNotesCaptureGroups["platform"]
        category = releaseNotesCaptureGroups["category"]

        case platform
          when "ANDROID"
            labels.push "Android"
          when  "CLI"
            labels.push "CLI :computer:"
          when  "DOCS"
            labels.push "Docs :blue_book:"
          when  "IOS"
            labels.push "iOS :iphone:"
          when  "TVOS"
            labels.push "tvOS :tv:"
          when  "WINDOWS"
            labels.push "Windows"
        end

        case category
          when "BREAKING"
            labels.push "Breaking Change :boom:"
          when "BUGFIX"
            labels.push "Bug Fix :bug:"
          when "ENHANCEMENT"
            labels.push "Feature Request :star2:"
          when "FEATURE"
            labels.push "Feature Request :star2:"
          when "MINOR"
            labels.push "Minor Change"
        end

        Octokit.remove_label(@repo, pr.number, label_no_release_notes) if pr.labels.include?(label_no_release_notes)
      else
        labels.push label_no_release_notes unless pr.labels.include?(label_no_release_notes)

        Octokit.remove_label(@repo, pr.number, label_release_notes) if pr.labels.include?(label_release_notes)
      end

      puts "--> #{labels}"
      Octokit.add_labels_to_an_issue(@repo, pr.number, labels)
    end

    def lint_pr(pr)
      labels = []
      comments = Octokit.issue_comments(@repo, pr.number)
      is_large_pr = comments.any? { |c| c.body =~ /:exclamation: Big PR/ }

      if is_large_pr
        label = "Large PR :bangbang:"
        labels.push label unless pr.labels.include?(label)
      end

      body = strip_comments(pr.body)
      has_test_plan = body.downcase =~ /test plan/

      unless has_test_plan
        label = "No Test Plan :clipboard:"
        labels.push label unless pr.labels.include?(label)
      end

      from_core_contributor = @core_contributors.include? pr.user.login 

      if from_core_contributor
        label = "Core Team"
        labels.push label unless pr.labels.include?(label)
      end

      if labels.count > 0
        Octokit.add_labels_to_an_issue(@repo, pr.number, labels)
      end
    end

  end
end