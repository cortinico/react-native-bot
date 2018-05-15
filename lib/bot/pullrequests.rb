require 'octokit'
require 'active_support/all'

module Bot
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
        "kelset",
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
        puts "#{@repo}: [PR] Found #{prs.items.count} PRs for candidate #{candidate[:action]}..."
        prs.items.each do |pr|
          process(pr, candidate)
        end
      end
    end

    def candidates
      [
        {
          :search => "repo:#{@repo} is:pr is:open created:>=#{2.days.ago.to_date.to_s}",
          :action => 'lint_pr'
        },
        {
          :search => "repo:#{@repo} is:open is:pr -label:\":clipboard:Release Notes\" -label:\":clipboard:No Release Notes\" created:>=#{2.days.ago.to_date.to_s}",
          :action => 'check_release_notes'
        },
        {
          :search => "repo:#{@repo} is:open is:pr label:\":clipboard:No Release Notes\" updated:>=#{2.days.ago.to_date.to_s}",
          :action => 'check_release_notes'
        }
      ]
    end

    def strip_comments(text)
      regex = /(?=<!--)([\s\S]*?-->)/m
      text.gsub(regex, "")
    end

    def process(pr, candidate)
      puts "#{@repo}: [PR] Processing #{pr.html_url}: #{pr.title}"

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
      label_release_notes = ":clipboard:Release Notes"
      label_no_release_notes = ":clipboard:No Release Notes"

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
            label = ":large_blue_diamond:Android"
            labels.push
          when  "CLI"
            label = ":computer:CLI"
            labels.push
          when  "DOCS"
            label = ":no_entry_sign:Docs"
            labels.push
          when  "IOS"
            label = ":large_blue_diamond:iOS"
            labels.push
          when  "TVOS"
            label = ":large_blue_diamond:tvOS"
            labels.push
          when  "WINDOWS"
            label = ":small_blue_diamond:Windows"
            labels.push
          when  "MACOS"
            label = ":small_blue_diamond:macOS"
            labels.push
          when  "LINUX"
            label = ":small_blue_diamond:Linux"
            labels.push
        end

        case category
          when "BREAKING"
            label = ":boom:Breaking Change"
            labels.push
          when "BUGFIX"
            label = ":bug:Bug Fix"
            labels.push
          when "ENHANCEMENT"
            label = ":star2:Enhancement PR"
            labels.push
          when "FEATURE"
            label = ":star2:Feature Request"
            labels.push
          when "MINOR"
            label = "Minor Change"
            labels.push
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
        label = ":clipboard:Large PR :bangbang:"
        labels.push label unless pr.labels.include?(label)
      end

      body = strip_comments(pr.body)
      has_test_plan = body.downcase =~ /test plan/

      unless has_test_plan
        label = ":clipboard:No Test Plan"
        labels.push label unless pr.labels.include?(label)
      end

      from_core_contributor = @core_contributors.include? pr.user.login

      if from_core_contributor
        label = "Core Team"
        labels.push label unless pr.labels.include?(label)
      end

      add_labels(pr, labels)
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

  end
end
