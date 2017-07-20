require 'active_support/all'
require 'byebug'
require 'httparty'

module Iceboxer
  class Canny

    def self.create_issue(issue, github_url, company_name, board_id)
      uri = "https://#{company_name}.canny.io/api/posts/create"
      headers = {'Cookie' => ENV['CANNY_COOKIE']}
      data = {
        boardID: board_id,
        details: "Moved from #{github_url}",
        title: issue.title,
        imageURLs: [].to_json
      }

      result = JSON.parse(HTTParty.post(uri, {body: data, headers: headers}))
      "https://#{company_name}.canny.io/#{result['post']['board']['urlName']}/p/#{result['post']['urlName']}"
    end

  end
end
