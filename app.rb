require 'rubygems'
require 'sinatra'
require 'boxr'
require 'dotenv'; Dotenv.load(".env")
#require 'twilio-ruby'
require 'awesome_print'
require 'ap'

MAX_REFRESH_TIME = 1800

$tokens = nil
$prevTime = 1

# get '/' do
#   "Hello, world"
# end


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

  # for debugging purposes to determine how long it's been since last refresh
  timeDiff = Time.now.to_i - Integer($prevTime)
  puts "Time diff: #{timeDiff}"

  # if the program has just been launched, create new access token, else create new client obj
  if($tokens && (Time.now.to_i - Integer($prevTime)) < MAX_REFRESH_TIME)
    client = Boxr::Client.new(ENV['ACCESS_TOKEN'])
  else
    token_refresh_callback
    client = Boxr::Client.new(ENV['ACCESS_TOKEN'])
    $prevTime = Time.new.to_i
    puts "Token expired or first token generation"
  end


  # if acces token has expired, called token_refresh_callbacK NOT USED ANYMORE!
=begin
  client = Boxr::Client.new(ENV['ACCESS_TOKEN'],
                              refresh_token: ENV['REFRESH_TOKEN'],
                              client_id: ENV['BOX_CLIENT_ID'],
                              client_secret: ENV['BOX_CLIENT_SECRET'],
                              &token_refresh_callback)
=end

  # get items in root folder
  items = client.folder_items(Boxr::ROOT)

  # Create new company folder
  path = '/Sales/Company-Leads'
  folder = client.folder_from_path(path)
  new_folder = client.create_folder(companyName, folder)

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
  uploaded_file = client.upload_file('./lead-information.docx', new_folder)
  File.delete('./lead-information.docx')

  # create task for Andy Dufresne
  task = client.create_task(uploaded_file, action: :review, message: "Please review, thanks!", due_at: nil)
  client.create_task_assignment(task, assign_to: "237685143", assign_to_login: nil)

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

  #erb :thank_you
  File.new('views/thank_you.erb').readlines
end

# called when access token has expired, refreshes the access token
def token_refresh_callback

  # refresh the refresh/access tokens
  $tokens = Boxr::refresh_tokens(ENV['REFRESH_TOKEN'], client_id: ENV['BOX_CLIENT_ID'], client_secret: ENV['BOX_CLIENT_SECRET'])

  #ap $tokens

  refresh_env_file($tokens.access_token, $tokens.refresh_token)

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

  $tokens = Boxr::get_tokens(code)
  ap $tokens

  refresh_env_file($tokens.access_token, $tokens.refresh_token)

  puts "Access/refresh tokens have been initialized"

end

get '/thankyou' do
  File.new('views/thank_you.erb').readlines
end

get '/form-upload' do
  $client.upload_file('wailer.png', 0)
  File.new('views/thank_you.erb').readlines


end
