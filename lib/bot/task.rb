require 'octokit'
require 'active_support/all'

module Bot

  # These should be handled by a webhook, ideally
  @@frequentOperations = [
    Bot::Events
  ]

  @@hourlyOperations = [
    Bot::Closer,
    Bot::Labeler,
    Bot::Template,
    Bot::PullRequests,
    Bot::OldVersion
  ]

  @@dailyOperations = [
  ]

  def self.runDaily
    unless ENV['GITHUB_API_TOKEN'].present?
      raise "Set GITHUB_API_TOKEN with a token with repo access"
    end

    unless ENV['BOT_REPOS'].present?
      raise "Set BOT_REPOS to repo(s) like 'org/repo1, org/repo2'"
    end

    Octokit.access_token = ENV['GITHUB_API_TOKEN']
    repositories = ENV["BOT_REPOS"].split(',').map(&:strip)

    puts "#{Octokit.rate_limit!.remaining} core API requests remaining... (search is limited to 30 req/min)"

    @@dailyOperations.each do |op|
      repositories.each do |repository|
        op.new(repository).perform
      end
    end

  end

  def self.runHourly
    unless ENV['GITHUB_API_TOKEN'].present?
      raise "Set GITHUB_API_TOKEN with a token with repo access"
    end

    unless ENV['BOT_REPOS'].present?
      raise "Set BOT_REPOS to repo(s) like 'org/repo1, org/repo2'"
    end

    Octokit.access_token = ENV['GITHUB_API_TOKEN']
    repositories = ENV["BOT_REPOS"].split(',').map(&:strip)

    puts "#{Octokit.rate_limit!.remaining} core API requests remaining... (search is limited to 30 req/min)"

    @@hourlyOperations.each do |op|
      repositories.each do |repository|
        op.new(repository).perform
      end
    end
  end

  def self.runFrequently
    unless ENV['GITHUB_API_TOKEN'].present?
      raise "Set GITHUB_API_TOKEN with a token with repo access"
    end

    unless ENV['BOT_REPOS'].present?
      raise "Set BOT_REPOS to repo(s) like 'org/repo1, org/repo2'"
    end

    Octokit.access_token = ENV['GITHUB_API_TOKEN']
    repositories = ENV["BOT_REPOS"].split(',').map(&:strip)

    puts "#{Octokit.rate_limit!.remaining} core API requests remaining... (search is limited to 30 req/min)"

    @@frequentOperations.each do |op|
      repositories.each do |repository|
        op.new(repository).perform
      end
    end
  end
end
