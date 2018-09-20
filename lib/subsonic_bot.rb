#ruby
require 'bundler/setup'
require 'sinatra'
require 'typhoeus'
require 'dotenv'
require 'net/http'
require 'uri'
require 'digest'
require 'json'
require 'pry'

Dotenv.load

module SubsonicBot
  class Subsonic
    def self.get_random_song
      res = make_subsonic_call("getRandomSongs", "&size=1")

      song = res["subsonic-response"]["randomSongs"]["song"].first
      description = "#{song["artist"].gsub(/[^0-9A-Za-z]/, '')}-#{song["title"].gsub(/[^0-9A-Za-z]/, '')}"
      cover_art = song["coverArt"]

      share_url = create_share(song["id"], description)

      "#{song["artist"]} - #{song["title"]}\n#{share_url}"
    end

    def self.get_random_album
      res = make_subsonic_call("getAlbumList", "&size=1&type=random")

      album = res["subsonic-response"]["albumList"]["album"].first
      album_description = "#{album["artist"].gsub(/[^0-9A-Za-z]/, '')}-#{album["title"].gsub(/[^0-9A-Za-z]/, '')}"

      share_url = create_share(album["id"], description)

      "#{album["artist"]} - #{album["title"]}\n#{share_url}"
    end

    def self.create_share(asset_id, asset_description)
      res = make_subsonic_call("createShare", "&id=#{asset_id}&description=#{asset_description}")

      share = res["subsonic-response"]["shares"]["share"].first
      share["url"]
    end

    def self.make_subsonic_call(call_name, options=nil)
      server   = "#{ENV["SUBSONIC_SERVER"]}"
      version  = "#{ENV['VERSION']}"
      client   = "#{ENV['CLIENT']}"
      username = "#{ENV['USERNAME']}"
      password = "#{ENV['PASSWORD']}"
      salt     = "#{ENV['SALT']}"
      token    = Digest::MD5.hexdigest(password + salt)

      location  = "#{server}/rest/#{call_name}.view?u=#{username}&t=#{token}&s=#{salt}&v=#{version}&c=#{client}&f=json"
      location += options

      uri = URI.parse(location)
      req = Net::HTTP::Get.new(uri.to_s)
      res = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }

      JSON.parse(res.body)
    end
  end

  class Web < Sinatra::Base
    #before do
      #return 401 unless request["token"] == ENV['SLACK_TOKEN']
    #end

    def get_random_song
      SubsonicBot::Subsonic.get_random_song
    end

    def get_random_album
      SubsonicBot::Subsonic.get_random_album
    end

    def help_string
      help_string  = "To use Subsonic Bot try typing 'subsonic song (optional: song name)' or 'subsonic album (optional: artist)'\n"
      help_string += "EX: subsonic artist Foo Fighters"
    end

    def slack_response_hash(output)
      {username: 'subsonicbot', icon_emoji: ':musical_note:', text: output}.to_json
    end

    # Coming in from Slack
    post "/subsonic" do
      # This is the bot trigger word
      return if !params[:trigger_word]

      # This is the bot command. Return the help text if no command given.
      if !params[:text]
        return slack_response_hash(help_string)
      end

      input = params[:text].gsub(params[:trigger_word], "").strip

      # TODO: Improve error handling to pass on the actual error.
      begin
        @output = case input
        when "song"
          get_random_song
        when "album"
          get_random_album
        else 
          help_string
        end
      rescue
        @output = "Bzzz.. (smoke) Prrzzt.. <robot voice>Cannot complete your request at this time</robot voice>."
      end

      status 200

      return slack_response_hash(@output)
    end
  end
end
