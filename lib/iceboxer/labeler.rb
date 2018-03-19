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
          puts "Processing #{@repo}/issues/#{issue.number}: #{issue.title}"
          label_based_on_title(issue)
        end
      end
    end

    def candidates
      [
        {
          :search => "repo:#{@repo} is:open created:>#{1.day.ago.to_date.to_s}"
        }
      ]
    end

    def label_based_on_title(issue)
      issue_title = issue.title.downcase

      labels = []
      labels.push "Android" if issue_title =~ /android/
      labels.push "iOS :iphone:" if issue_title =~ /ios/
      labels.push "tvOS :tv:" if issue_title =~ /tvos/
      labels.push "WebView" if issue_title =~ /webview/
      labels.push "Animated" if issue_title =~ /animated/
      labels.push "TextInput" if issue_title =~ /textinput/
      labels.push "Lists :scroll:" if issue_title =~ /sectionlist/
      labels.push "Lists :scroll:" if issue_title =~ /flatlist/
      labels.push "Lists :scroll:" if issue_title =~ /virtualizedlist/
      labels.push "CLI :computer:" if issue_title =~ /react-native upgrade/
      labels.push "CLI :computer:" if issue_title =~ /react-native link/
      labels.push "Networking :globe_with_meridians:" if issue_title =~ /netinfo/
      labels.push "Networking :globe_with_meridians:" if issue_title =~ /fetch/
      labels.push "Networking :globe_with_meridians:" if issue_title =~ /okhttp/
      labels.push "Networking :globe_with_meridians:" if issue_title =~ /http/

      add_labels(issue, labels)
    end

    def add_labels(issue, labels)
      new_labels = []

      labels.each do |label|
        new_labels.push label unless issue_contains_label(issue, label)
      end

      if new_labels.count > 0
        puts "Adding labels to #{issue.html_url} --> #{new_labels}"
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