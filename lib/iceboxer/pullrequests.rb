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
          :search => "repo:#{@repo} is:open -label:\"Core Team\" created:>#{1.hour.ago.to_date.to_s}",
          :action => 'check_core_team'
        },
        {
          :search => "repo:#{@repo} is:open is:pr -label:\"Release Notes :clipboard:\" -label:\"No Release Notes :clipboard:\" created:>#{1.hour.ago.to_date.to_s}",
          :action => 'check_release_notes'
        },
        {
          :search => "repo:#{@repo} is:open is:pr label:\"No Release Notes :clipboard:\" updated:>#{1.hour.ago.to_date.to_s}",
          :action => 'check_release_notes'
        }                
      ]
    end

    def strip_comments(pr)
      body = pr.body
      regex = /(?=<!--)([\s\S]*?-->)/m
      body.gsub(regex, "")
    end

    def process(pr, candidate)
      if candidate[:action] == 'check_release_notes'
        check_release_notes(pr)
      end
      if candidate[:action] == 'check_core_team'
        check_core_team(pr)
      end
    end

    def check_release_notes(pr)
      releaseNotesRegex = /\[\s?(?<platform>ANDROID|CLI|DOCS|GENERAL|INTERNAL|IOS|TVOS|WINDOWS)\s?\]\s*?\[\s?(?<category>BREAKING|BUGFIX|ENHANCEMENT|FEATURE|MINOR)\s?\]\s*?\[(.*)\]\s*?\-\s*?(.*)/

      body = strip_comments(pr)
      releaseNotesCaptureGroups = releaseNotesRegex.match(body)
      labels = ["Ran Commands"]
      if releaseNotesCaptureGroups
        labels.push "Release Notes :clipboard:" unless pr.labels.include? "Release Notes :clipboard:"

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

        Octokit.remove_label(@repo, pr.number, "No Release Notes :clipboard:") if pr.labels.include? "No Release Notes :clipboard:"
      else
        labels.push "No Release Notes :clipboard:" unless pr.labels.include? "No Release Notes :clipboard:"

        Octokit.remove_label(@repo, pr.number, "Release Notes :clipboard:") if pr.labels.include? "Release Notes :clipboard:"
      end

      puts "--> #{labels}"
      Octokit.add_labels_to_an_issue(@repo, pr.number, labels)
    end

    def check_core_team(pr)
      if @core_contributors.include? pr.user.login 
        Octokit.add_labels_to_an_issue(@repo, pr.number, ["Core Team"]) unless pr.labels.include? "Core Team"
      end
    end
  end
end