require 'octokit'
require 'active_support/all'

module Iceboxer
  class Labeler

    def initialize(repo)
      @repo = repo
    end

    def perform
      candidates.each do |candidate|
        issues = Octokit.search_issues(candidate[:search])
        puts "#{@repo}: [LABELER] Found #{issues.items.count} recently created issues..."
        issues.items.each do |issue|
          puts "#{@repo}: [LABELER] Processing #{issue.html_url}: #{issue.title}"
          label_based_on_title(issue)
        end
      end
    end

    def candidates
      [
        {
          :search => "repo:#{@repo} is:open created:>=#{1.day.ago.to_date.to_s}"
        }
      ]
    end

    def label_based_on_title(issue)
      issue_title = issue.title.downcase

      labels = []
      labels.push ":large_blue_diamond:Android" if issue_title =~ /android/
      labels.push ":large_blue_diamond:iOS" if issue_title =~ /ios/
      labels.push ":large_blue_diamond:tvOS" if issue_title =~ /tvos/
      labels.push ":large_orange_diamond:WebView" if issue_title =~ /webview/
      labels.push ":large_orange_diamond:Animated" if issue_title =~ /animated/
      labels.push ":large_orange_diamond:TextInput" if issue_title =~ /textinput/
      labels.push ":large_orange_diamond:Lists" if issue_title =~ /sectionlist/
      labels.push ":large_orange_diamond:Lists" if issue_title =~ /flatlist/
      labels.push ":large_orange_diamond:Lists" if issue_title =~ /virtualizedlist/
      labels.push ":computer:CLI" if issue_title =~ /react-native upgrade/
      labels.push ":computer:CLI" if issue_title =~ /react-native link/
      labels.push ":computer:CLI" if issue_title =~ /local-cli/
      labels.push ":globe_with_meridians:Networking" if issue_title =~ /xhr/
      labels.push ":globe_with_meridians:Networking" if issue_title =~ /netinfo/
      labels.push ":globe_with_meridians:Networking" if issue_title =~ /fetch/
      labels.push ":globe_with_meridians:Networking" if issue_title =~ /okhttp/
      labels.push ":globe_with_meridians:Networking" if issue_title =~ /http/
      labels.push ":warning:Regression" if issue_title =~ /regression/

      add_labels(issue, labels)
    end

    def add_labels(issue, labels)
      new_labels = []

      labels.each do |label|
        new_labels.push label unless issue_contains_label(issue, label)
      end

      if new_labels.count > 0
        puts "#{@repo}: [LABELS] 📍 #{issue.html_url} --> Adding #{new_labels}"
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