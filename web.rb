require 'rubygems'
require 'sinatra'
require 'boxr'
#require 'twilio-ruby'
require 'awesome_print'
require 'ap'
require 'dotenv'; Dotenv.load(".env")

require_relative './app/oauth2'

# oauth object used for using refresh methods
$oauth = Oauth2.new
$client = nil

set :server, 'webrick'

get '/' do
  erb 'Can you handle a <a href="/secure/place">secret</a>?'
end

get '/' do
  @notes = Note.all :order => :id.desc
  @title = 'All Notes'

  erb :layout
end

post '/submit' do

  companyName = params[:company]
  info = params[:info]
  folderExists = false
  path = '/CMS-Energy'

  # for DEBUGGING purposes to determine how long it's been since last refresh
  timeDiff = Time.now.to_i - Integer(Oauth2.prevTime)
  puts "Time diff: #{timeDiff}"

  # if true (need new client obj?) create new client
  if($oauth.need_new_tokens())
    $client = Boxr::Client.new(Oauth2.tokens.access_token)
  end

  # Create new company folder
  folder = $client.folder_from_path(path)

  checkFolder = $client.folder_items(folder)

  if(companyName == "")
    companyName = "Default Company"
  end

  # see if company folder already exists. If it does, just redirect
  checkFolder.each do |item|

    if(item.name == companyName)
      folderExists = true
      puts "Error: Folder with that name already exists"
    end

  end

  # if company name doesn't already exist, create new folder/upload doc
  if(!folderExists)

    new_folder = $client.create_folder(companyName, folder)

    # create and populate new file
    file = File.open('lead-information.docx', 'w')
    file.puts "Company: #{params[:company]}"
    file.puts "Name: #{params[:name]}"
    file.puts "Email: #{params[:email]}"
    file.puts "Message: #{params[:message]}"
    file.puts "Phone Number: #{params[:phone]}"
    file.puts
    file.puts "SDR Call Notes: "
    file.close

    # upload new file, then remove from local dir
    uploaded_file = $client.upload_file('./lead-information.docx', new_folder)
    File.delete('./lead-information.docx')

    # create task for Andy Dufresne
    task = $client.create_task(uploaded_file, action: :review, message: "Please review, thanks!", due_at: nil)
    $client.create_task_assignment(task, assign_to: "237685143", assign_to_login: nil)

=begin
    # Twilio API Call
    account_sid = "AC4c44fc31f1d7446784b3e065f92eb4e6"
    auth_token = "5ad821b20cff339979cd0a9d42e1a05d"
    client = Twilio::REST::Client.new account_sid, auth_token

    from = "+14087695509" # Your Twilio number

    friends = {
  # "+16504171570" => "Cary",
  # "+18053451948" => "Joann",
  #  "+15615122265" => "Austin",
  # "+16502797331" => "Matt",
  #"+16504501439" => "Jane",
  # "+16504171570" => "Cary",
  # "+16613404762" => "Jared"
  # "+18052188632" => "David Lasher",
  # "+16504547616" => "ZT"
    }
    friends.each do |key, value|
      client.account.messages.create(
          :from => from,
          :to => key,
          :body => "Hey #{value}, heads up! A new opportunity has submitted a form on the '/emailblast' landing page. Please follow up on this!"
      )
      puts "Sent message to #{value}"
    end
=end
  else
    File.new('views/layout.erb').readlines
  end

  #erb :thank_you
  File.new('views/thank_you.erb').readlines
end

get '/submit' do
  File.new('views/thank_you.erb').readlines
end

  # only need to call this once every 60 days, when refresh token expires
  get '/init_tokens' do

    # Chad oauth code
    oauth_url = Boxr::oauth_url(URI.encode_www_form_component('your-anti-forgery-token'))

    puts "Copy the URL below and paste into a browser. Go through the OAuth flow using the desired Box account. \
    When you are finished your browser will redirect to a 404 error page. This is expected behavior. Look at the URL in the address \
    bar and copy the 'code' parameter value. Paste it into the prompt below. You only have 30 seconds to complete this task so be quick about it! \
    You will then see your access token and refresh token."

    puts
    puts "URL:  #{oauth_url}"
    puts

    print "Enter the code: "
    code = STDIN.gets.chomp.split('=').last

    $oauth.set_tokens(Boxr::get_tokens(code))
    ap Oauth2.tokens


    $oauth.refresh_env_file(Oauth2.tokens.access_token, Oauth2.tokens.refresh_token)

    puts "Access/refresh tokens have been initialized"

  end

get '/form-upload' do

  path = '/CMS-Energy'

  # if true (need new client obj?) create new client
  if($oauth.need_new_tokens())
    $client = Boxr::Client.new(Oauth2.tokens.access_token)
  end

  # Move to CMS Folder
  folder = $client.folder_from_path(path)

  $client.upload_file('test.txt', folder)
  File.new('views/thank_you.erb').readlines
end




