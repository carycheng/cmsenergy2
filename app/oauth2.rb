require 'rubygems'
require 'sinatra'
require 'boxr'
require 'awesome_print'
require 'ap'
require 'dotenv'; Dotenv.load(".env")

# 30 minute refresh limit for access token
MAX_REFRESH_TIME = 1800

class Oauth2
  public

  @@tokens = nil # represents valid generated tokens
  @@prevTime = 1

  def self.prevTime
    @@prevTime
  end

  def self.tokens
    @@tokens
  end  

  def set_tokens(tok)
    @@tokens = tok
  end

  # called when access token has expired, refreshes the access token
  def token_refresh_callback

    # refresh the refresh/access tokens
    # if token obj is not null, grab token from instance variable, else grab from ENV file
    if(!@@tokens)
      @@tokens = Boxr::refresh_tokens(ENV['REFRESH_TOKEN'], client_id: ENV['BOX_CLIENT_ID'], client_secret: ENV['BOX_CLIENT_SECRET'])
    else
      @@tokens = Boxr::refresh_tokens(@@tokens.refresh_token, client_id: ENV['BOX_CLIENT_ID'], client_secret: ENV['BOX_CLIENT_SECRET'])
    end

    refresh_env_file(@@tokens.access_token, @@tokens.refresh_token)
  end


  #  method that replaces ENV file contents with new valid tokens
  def refresh_env_file(access, refresh)

    # save local copy of client id/secret
    clientId = ENV['BOX_CLIENT_ID']
    clientSecret = ENV['BOX_CLIENT_SECRET']

    # open ENV file and update with new valid tokens
    file = File.open('.env', "r+")

    file.puts "ACCESS_TOKEN=#{access}"
    file.puts "REFRESH_TOKEN=#{refresh}"
    file.puts "BOX_CLIENT_SECRET=#{clientSecret}"
    file.puts "BOX_CLIENT_ID=#{clientId}"

    puts "Tokens have been re-initialized"

    file.close
  end

  # if the token obj has been initialized and the time since last refresh < 30 min
  # then do not refresh tokens/create new client
  def new_client
    
    if(@@tokens && (Time.now.to_i - Integer(@@prevTime)) < MAX_REFRESH_TIME)
      puts "Client obj created"
      return false
    else   
      token_refresh_callback
      @@prevTime = Time.new.to_i
      puts "Token expired or first token generation"
      return true
    end
  end

end