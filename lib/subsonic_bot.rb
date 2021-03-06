#ruby
require 'bundler/setup'
require 'sinatra'
require 'dotenv'
require 'net/http'
require 'uri'
require 'digest'
require 'json'
require 'pry'

Dotenv.load

module SubsonicBot
  class Subsonic
    def self.parse_response(response, response_object)
      asset = response["subsonic-response"][response_object[:call]][response_object[:type]].sample
      { 
        id:          asset["id"],
        artist:      asset["artist"],
        title:       asset["title"],
        cover_art:   asset["coverArt"],
        description: "#{asset["artist"].gsub(/[^0-9A-Za-z]/, '')}-#{asset["title"].gsub(/[^0-9A-Za-z]/, '')}"
      }
    end

    def self.clear_playlist
      make_subsonic_call("jukeboxControl", "&action=clear")
    end

    def self.start_playlist
      make_subsonic_call("jukeboxControl", "&action=start")
    end

    def self.play_on_jukebox(id)
      clear_playlist
      make_subsonic_call("jukeboxControl", "&action=add&id=#{id}")
      start_playlist
    end

    def self.get_random_song
      song = parse_response(make_subsonic_call("getRandomSongs", "&size=1"), {type: "song", call: "randomSongs"})
      share_url = create_share(song[:id], song[:description])
      play_on_jukebox(song[:id])

      "#{song[:artist]} - #{song[:title]}\n#{share_url}"
    end

    def self.get_random_album
      album = parse_response(make_subsonic_call("getAlbumList", "&size=1&type=random"), {type: "album", call: "albumList"})
      share_url = create_share(album[:id], album[:description])
      play_on_jukebox(album[:id])

      "#{album[:artist]} - #{album[:title]}\n#{share_url}"
    end

    def self.create_share(asset_id, asset_description)
      response = make_subsonic_call("createShare", "&id=#{asset_id}&description=#{asset_description}")

      share = response["subsonic-response"]["shares"]["share"].first
      share["url"]
    end

    def self.search(type, query_params)
      asset = parse_response(make_subsonic_call("search", query_params), {type: "match", call: "searchResult"})
      share_url = create_share(asset[:id], asset[:description])
      play_on_jukebox(asset[:id])

      "#{asset[:artist]} - #{asset[:title]}\n#{share_url}"
    end

    def self.make_subsonic_call(call_name, query_params=nil)
      server   = "#{ENV["SUBSONIC_SERVER"]}"
      version  = "#{ENV['VERSION']}"
      client   = "#{ENV['CLIENT']}"
      username = "#{ENV['USERNAME']}"
      password = "#{ENV['PASSWORD']}"
      salt     = Digest::SHA1.hexdigest([Time.now, rand].join)
      token    = Digest::MD5.hexdigest(password + salt)

      location  = "#{server}/rest/#{call_name}.view?u=#{username}&t=#{token}&s=#{salt}&v=#{version}&c=#{client}&f=json"
      location += query_params

      uri = URI.parse(location)
      request  = Net::HTTP::Get.new(uri.to_s)
      response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }

      JSON.parse(response.body)
    end
  end

  class Web < Sinatra::Base
    #before do
      #return 401 unless request["token"] == ENV['SLACK_TOKEN']
    #end

    def get_song(search_string = nil)
      if search_string != nil
        SubsonicBot::Subsonic.search(:title, "&title=#{search_string}")
      else
        SubsonicBot::Subsonic.get_random_song
      end
    end

    def get_album(search_string = nil)
      if search_string != nil
        SubsonicBot::Subsonic.search(:album, "&album=#{search_string}")
      else
        SubsonicBot::Subsonic.get_random_album
      end
    end

    def get_artist(search_string = nil)
      if search_string != nil
        SubsonicBot::Subsonic.search(:artist, "&artist=#{search_string}")
      else
        SubsonicBot::Subsonic.get_random_album
      end
    end

    def help_string
      help_string  = "To use Subsonic Bot try typing:\n"
      help_string += "subsonic song (optional: song name)\n"
      help_string += "subsonic album (optional: artist)\n"
      help_string += "subsonic artist (optional: artist)\n"
      help_string += "subsonic song Evolution\n\n"
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
      search_string = input.partition(" ").reject{ |s| s == " " || s == "" }
      bot_command = search_string.shift
      search_string = search_string.first
      
      # TODO: Improve error handling to pass on the actual error.
      begin
        @output = case bot_command
        when /^song/
          get_song(search_string)
        when /^album/
          get_album(search_string)
        when /^artist/
          get_artist(search_string)
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
