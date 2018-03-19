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
      labels = []
      if releaseNotesCaptureGroups

        labels.push label_release_notes unless pr.labels.include?(label_release_notes)

        platform = releaseNotesCaptureGroups["platform"]
        category = releaseNotesCaptureGroups["category"]

        case platform
          when "ANDROID"
            label = "Android"
            labels.push label unless pr.labels.include? label
          when  "CLI"
            label = "CLI :computer:"
            labels.push label unless pr.labels.include? label
          when  "DOCS"
            label = "Docs :blue_book:"
            labels.push label unless pr.labels.include? label
          when  "IOS"
            label = "iOS :iphone:"
            labels.push label unless pr.labels.include? label
          when  "TVOS"
            label = "tvOS :tv:"
            labels.push label unless pr.labels.include? label
          when  "WINDOWS"
            label = "Windows"
            labels.push label unless pr.labels.include? label
        end

        case category
          when "BREAKING"
            label = "Breaking Change :boom:"
            labels.push label unless pr.labels.include? label
          when "BUGFIX"
            label = "Bug Fix :bug:"
            labels.push label unless pr.labels.include? label
          when "ENHANCEMENT"
            label = "Feature Request :star2:"
            labels.push label unless pr.labels.include? label
          when "FEATURE"
            label = "Feature Request :star2:"
            labels.push label unless pr.labels.include? label
          when "MINOR"
            label = "Minor Change"
            labels.push label unless pr.labels.include? label
        end

        remove_label(pr, label_no_release_notes)
      else
        labels.push label_no_release_notes unless pr.labels.include?(label_no_release_notes)

        remove_label(pr, label_release_notes)
      end

      if labels.count > 0
        add_labels(pr, labels)
      end
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

      add_labels(pr, labels)
    end

    def add_labels(pr, labels)
      new_labels = []

      labels.each do |label|
        new_labels.push label unless issue_contains_label(pr, label)
      end

      if new_labels.count > 0
        puts "Adding labels to #{pr.html_url} --> #{new_labels}"
        Octokit.add_labels_to_an_issue(@repo, pr.number, new_labels)
      end

    end

    def remove_label(pr, label)
      if pr.labels.include? label
        puts "Removing label -> #{label}" if issue_contains_label(pr, label)
        Octokit.remove_label(@repo, pr.number, label)
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