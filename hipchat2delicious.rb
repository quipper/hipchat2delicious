require 'active_support/all'
require 'hipchat-api'
require 'www/delicious'
require 'nokogiri'
require 'tapp'
require 'redis'

URL_REGEX = /https?:\/\/[\S]+/
uri = URI.parse(ENV["REDISTOGO_URL"] || "redis://localhost:6379")
REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

class Hipchat2Delicious

  def self.run
    while true
      delicious = WWW::Delicious.new(ENV["DELICIOUS_USERNAME"], ENV["DELICIOUS_PASSWORD"])

      hipchat = HipChat::API.new(ENV["HIPCHAT_TOKEN"])
      hipchat.rooms_history(ENV["HIPCHAT_ROOM_ID"], "recent", "Europe/London").parsed_response["messages"].each do |m|
        m["message"].scan(URL_REGEX).each do |url|
          next if REDIS.get(url)
          begin
            p "url posted in hipchat: #{url}"
            response = HTTParty.get(url)
            if response.code == 200
              page = Nokogiri::HTML(response.body)
              title = page.css("title").try(:first).try(:text) || url
              delicious.posts_add(:url => url, :title => title)
              hipchat.rooms_message(ENV["HIPCHAT_ROOM_ID"], "delicious", "Saved: <a href=\"http://delicious.com/#{ENV["DELICIOUS_USERNAME"]}\">delicious</a>", notify=0)

              REDIS.set(url, true)
            end
          rescue URI::InvalidURIError
          rescue SocketError
          rescue Errno::ECONNREFUSED
          end
        end
      end
      p 'done. waiting 15 secs'
      sleep 15
    end
  end
end
