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
          label_based_on_envinfo(issue)
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

    def label_based_on_envinfo(issue)
      issue_body = strip_comments issue.body
      regex = /OS:\s?(?<OS>macOS|Windows|Linux)/

      envinfo = regex.match(issue_body)

      new_labels = []

      if envinfo
        case envinfo["OS"]
          when "Windows"
            label = ":small_blue_diamond:Windows"
            new_labels.push label
          when "Linux"
            label = ":small_blue_diamond:Linux"
            new_labels.push label
          when "macOS"
            label = ":small_blue_diamond:macOS"
            new_labels.push label
        end
      end

      add_labels(issue, new_labels)
    end

    def strip_comments(text)
      regex = /(?=<!--)([\s\S]*?-->)/m
      text.gsub(regex, "")
    end

    def add_labels(issue, labels)
      new_labels = []

      labels.each do |label|
        if label
          new_labels.push label unless issue_contains_label(issue, label)
        end
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