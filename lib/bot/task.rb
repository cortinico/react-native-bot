require 'octokit'
require 'active_support/all'

module Bot

  @@operations = [
    Bot::Closer,
    Bot::Template,
    Bot::PullRequests,
    Bot::OldVersion,
    Bot::Labeler
  ]

  def self.run
    unless ENV['GITHUB_API_TOKEN'].present?
      raise "Set GITHUB_API_TOKEN with a token with repo access"
    end

    unless ENV['BOT_REPOS'].present?
      raise "Set BOT_REPOS to repo(s) like 'org/repo1, org/repo2'"
    end

    Octokit.access_token = ENV['GITHUB_API_TOKEN']
    repositories = ENV["BOT_REPOS"].split(',').map(&:strip)

    puts "#{Octokit.rate_limit!.remaining} core API requests remaining... (search is limited to 30 req/min)"

    @@operations.each do |op|
      repositories.each do |repository|
        op.new(repository).perform
      end
    end
  end
end
