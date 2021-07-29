require 'sinatra'
if Sinatra::Application.environment == :development
  require 'dotenv/load'
  require 'pry'
end

require "sinatra/activerecord"
require 'yaml'
require 'haml'
require 'open-uri'
require 'twilio-ruby'
require 'mailgun-ruby'
require 'rack-google-analytics'
require 'sinatra/flash'

#Constances for ENV
DB_HOST = ENV['DB_HOST']
DB_PORT = ENV['DB_PORT']
DB_USERNAME = ENV['DB_USERNAME']
DB_PASSWORD = ENV['DB_PASSWORD']
DB_NAME = ENV['DB_NAME']
SESSION_SECRET = ENV["SESSION_SECRET"]
TWILIO_NUMBER = ENV['TWILIO_NUMBER']
MY_NUMBER = ENV['MY_NUMBER']
ACCOUNT_SID = ENV['ACCOUNT_SID']
AUTH_TOKEN = ENV['AUTH_TOKEN']
MY_EMAIL = ENV['MY_EMAIL']
GA_TRACKER = ENV['GA_TRACKER']
MG_KEY = ENV['MG_KEY']
MG_SENDING_DOMAIN = ENV['MG_SENDING_DOMAIN']
MG_FROM_EMAIL = ENV['MG_FROM_EMAIL']

#Confirm ENV

#Enable Sessions
enable :sessions
set :session_secret, SESSION_SECRET

#Setup Google Analytics
use Rack::GoogleAnalytics, :tracker => GA_TRACKER

#Setup DBs
set :database_file, 'config/database.yml'


if Sinatra::Application.environment == :production
  ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])
else
  db_option = 'postgres://' + DB_USERNAME + ':' + DB_PASSWORD + '@' + DB_HOST + ":" + DB_PORT + '/' + DB_NAME
  ActiveRecord::Base.establish_connection(db_option)
end


#Require Models
current_dir = Dir.pwd
Dir["#{current_dir}/models/*.rb"].each { |file| require file }

#Helpers & AUTH
helpers do
  def title
    if @title
      "#{@title}"
    else
      "Sinatra Broadcast: Fly Them to the Moon"
    end
  end

  def current_user
    User.find(session[:user_id])
  end

  def logged_in?
    !!session[:user_id]
  end

  def redirect_if_not_logged_in
    if !logged_in?
      redirect "/login"
    end
  end
end

# First, instantiate the Twillio Client with your API Creds
client = Twilio::REST::Client.new ACCOUNT_SID, AUTH_TOKEN

# Public Routes
get '/' do
  if !logged_in?
    @broadcasts = Broadcast.order('updated_at DESC')
    @title = "Sinatra Broadcast: Fly Them to the Moon"
    haml :index
  else
    @broadcasts = Broadcast.order('updated_at DESC')
    @title = "Sinatra Broadcast: Fly Them to the Moon"
    haml :index
  end
end

get '/login' do
  @title = 'Sinatra Broadcast Login'
  haml :login
end

post '/login' do
  @user = User.find_by(username:params[:username])
  if @user && @user.authenticate(params[:password])
    session[:user_id] = @user.id
    redirect "/send"
  else
    flash[:message] = "We can't your login credentials. Please try again"
    redirect_if_not_logged_in
  end
end

get '/logout' do
  if logged_in?
    session.destroy
    redirect to '/login'
  else
    redirect to '/'
  end
end

get '/broadcasts/:id' do
  @broadcast = Broadcast.find(params[:id])
  haml :single_broadcast
end

get '/about' do
  @title = "About Sinatra Broadcast"
  haml :about
end

get '/subscribe' do
  @title = "Subscribe to Sinatra Broadcast"
  haml :subscribe
end

post '/subscribe' do
  name = params[:name]
  email = params[:email]
  body = params[:body]
  phone_number = params[:phone_number]

 
  # First, instantiate the Mailgun Client with your API key
  mg_client = Mailgun::Client.new MG_KEY


  # Define your message parameters
  message_params =  { 
    :from => 'subscribe@mg.example.com',
    :to =>   MY_EMAIL,
    :subject => "#{name} Would Like to Receive Broadcasts",
    :text => "Please add #{phone_number} to the sinatra broadcast. I would like to be added because #{body}",
  }

  # Send your message through the client
  mg_client.send_message MG_SENDING_DOMAIN, message_params

  haml :subscribe
  redirect '/thanks'
end

get '/thanks' do
  @title = "Thanks for Subscribing!"
  haml :thanks
end

# Protected Routes
get '/broadcasts' do
  if logged_in?
    @broadcasts = Broadcast.order('updated_at DESC')
    @title = "Broadcasts We Have Sent Out."
    haml :broadcasts
  else
    redirect_if_not_logged_in
  end
end

delete '/broadcasts/:id' do
  if logged_in?
    @broadcast = Broadcastl.find_by_id(params[:id])
    if @broadcast
    @broadcast.destroy
    else
    halt 404, "Broadcast not found"
    end

    200
    redirect '/broadcastss'
  else
    redirect_if_not_logged_in
  end
end

get '/contacts' do
  if logged_in?
    @contacts = Contact.order(:name)
    @title = "Contacts We Send To."
    haml :contacts
  else
    redirect_if_not_logged_in
  end
end

post '/contacts' do
  if logged_in?
    @contacts = Contact.create(name: params[:name], phone_number: params[:phone_number])
    redirect '/contacts'
  else
    redirect_if_not_logged_in
  end
end

get '/contacts/:id' do
  if logged_in?
    @contact = Contact.find(params[:id])
    haml :single_contact
  else
    redirect_if_not_logged_in
  end
end

delete '/contacts/:id' do
  if logged_in?
    @contact = Contact.find_by_id(params[:id])
    if @contact
    @contact.destroy
    else
    halt 404, "Contact not found"
    end

    200
    redirect '/contacts'
  else
    redirect_if_not_logged_in
  end
end

get '/send' do
  if logged_in?
    @title = "Send Your Broadcast."
    haml :send
  else
    redirect_if_not_logged_in
  end
end


post '/send' do
  if logged_in?
    #Save Broadcast to DB
    @broadcast = Broadcast.create(from: params[:from],subject: params[:subject], body: params[:body])
    #Send Saved Broadcast to MMS Twilio
    Contact.all.each do |contact|
      client.messages.create(
        from: TWILIO_NUMBER,
        to: contact.phone_number,
        body: @broadcast.body.to_s,
        media_url: '' #Need Images to get MMS to Join in Order, Not needed for SMS
      )
    end
    redirect '/'
  else
    redirect_if_not_logged_in
  end
end

get '/message' do
  if logged_in?
    "Things are Working!"
  else
    redirect_if_not_logged_in
  end
end

# MMS Routing using API REST, Modify for SMS Routing
post '/message' do
  if logged_in?
    from = params['From']
    body = params['Body']
    media_url = params['MediaUrl0']

    if from == MY_NUMBER
      Contact.all.each do |contact|
        message_params = {
          from: TWILIO_NUMBER,
          to: contact.phone_number,
          body: body.to_s
        }
        message_params [:media_url] = media_url if media_url.present?
        client.messages.create(message_params)
      end

    else
      contact = Contact.where(phone_number: from).first!
      body = "#{contact.name} (#{from}): \n#{body}"
      message_params = {
        from: TWILIO_NUMBER,
        to: MY_NUMBER,
        body: body.to_s
      }
      message_params [:media_url] = media_url if media_url.present?
      client.messages.create(message_params)
    end
  else
    redirect_if_not_logged_in
  end
end
