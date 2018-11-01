require 'octokit'
require 'active_support/all'

module Bot
  class PullRequests

    def initialize(repo)
      @repo = repo
      @label_no_test_plan = "📋No Test Plan"
      @label_has_test_plan = "✅Test Plan"
      @label_no_release_notes = "📋No Release Notes"
      @label_has_release_notes = "✅Release Notes"
      @label_large_pr = "‼ Large PR"
      @label_core_team = "Core Team"
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
        "hramos",
        "dryganets",
        "rigdern"
      ]
      @releaseNotesRegex = /\[\s?(?<platform>ANDROID|CLI|DOCS|GENERAL|INTERNAL|IOS|TVOS|WINDOWS|.*)\s?\]\s*?\[\s?(?<category>BREAKING|BUGFIX|ENHANCEMENT|FEATURE|MINOR)\s?\]\s*?\[(.*)\]\s*?\-\s*?(.*)/
    end

    def perform
      candidates.each do |candidate|
        prs = Octokit.search_issues(candidate[:search])
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
          :search => "repo:#{@repo} is:pr is:open updated:>=#{2.days.ago.to_date.to_s} label:\"#{@label_no_test_plan}\"",
          :action => 'lint_pr'
        },
        {
          :search => "repo:#{@repo} is:pr is:open updated:>=#{2.days.ago.to_date.to_s} label:\"#{@label_no_release_notes}\"",
          :action => 'lint_pr'
        },
        {
          :search => "repo:#{@repo} is:open is:pr -label:\"#{@label_has_release_notes}\" -label:\"#{@label_no_release_notes}\" created:>=#{2.days.ago.to_date.to_s}",
          :action => 'check_release_notes'
        },
        {
          :search => "repo:#{@repo} is:open is:pr label:\"#{@label_no_release_notes}\" updated:>=#{2.days.ago.to_date.to_s}",
          :action => 'check_release_notes'
        }
      ]
    end

    def strip_comments(text)
      return "" unless text
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


      body = strip_comments(pr.body)
      releaseNotesCaptureGroups = @releaseNotesRegex.match(body)
      labels = []
      if releaseNotesCaptureGroups
        labels.push @label_has_release_notes unless pr.labels.include?(@label_has_release_notes)

        platform = releaseNotesCaptureGroups["platform"]
        category = releaseNotesCaptureGroups["category"]

        case platform
          when "ANDROID"
            label = "🔷Android"
            labels.push label
          when  "CLI"
            label = "💻CLI"
            labels.push label
          when  "DOCS"
            label = "🚫Docs"
            labels.push label
          when  "IOS"
            label = "🔷iOS"
            labels.push label
          when  "TVOS"
            label = "🔷tvOS"
            labels.push label
          when  "WINDOWS"
            label = "🔷Windows"
            labels.push label
          when  "MACOS"
            label = "🔷macOS"
            labels.push label
          when  "LINUX"
            label = "🔷Linux"
            labels.push label
        end

        case category
          when "BREAKING"
            label = ":boom:Breaking Change"
            labels.push label
          when "BUGFIX"
            label = "🐛Bug Fix"
            labels.push label
          when "ENHANCEMENT"
            label = "🌟Enhancement PR"
            labels.push label
          when "FEATURE"
            label = "🌟Feature Request"
            labels.push label
          when "MINOR"
            label = "Minor"
            labels.push label
        end

        remove_label(pr, @label_no_release_notes)
      end

      if labels.count > 0
        add_labels(pr, labels)
      end
    end

    def lint_pr(pr)
      labels = []
      comments = Octokit.issue_comments(@repo, pr.number)
      labels.push @label_large_pr if comments.any? { |c| c.body =~ /:exclamation: Big PR/ }

      body = strip_comments(pr.body)
      has_test_plan = body.downcase =~ /test plan/

      if ! has_test_plan
        remove_label(pr, @label_has_test_plan)
      end

      releaseNotesCaptureGroups = @releaseNotesRegex.match(body)
      if releaseNotesCaptureGroups
        labels.push @label_has_release_notes
        remove_label(pr, @label_no_release_notes)
      end

      labels.push @label_core_team if @core_contributors.include? pr.user.login

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
