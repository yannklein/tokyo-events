require 'sinatra'
require "sinatra/json"
require 'sinatra/reloader'
require 'json'
require 'open-uri'
require "net/http"
require 'date'
require 'pry'

#Meetup gems
require "meetup_client"

# Gcal gems
require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"


CALENDAR_ID = "lewagon.org_b6cap1032jp9tcdcq74v4ute58@group.calendar.google.com"
TIME_ZONE = "Asia/Tokyo"
MEETUP_API_KEY = "9ip2qi4v6lr0j4nah575rh5kon"
MEETUP_URI = "https://tokyo-events.herokuapp.com/auth"
MEETUP_SECRET = "th3179nbuo35rd0ct5upk4kb8k"

get '/test' do
end

get '/run' do
  erb :run
end

get '/auth' do
  erb :auth
end

get '/populate' do
  p params
  p access_token = params[:access_token]
  p uri = URI("https://secure.meetup.com/oauth2/access?client_id=#{MEETUP_API_KEY}&client_secret=#{MEETUP_SECRET}&grant_type=authorization_code&redirect_uri=#{MEETUP_URI}&code=#{access_token}")
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true

  response = https.post(uri.path, headers)
  p credentials = JSON.parse(response)
  bearer = "Bearer #{credentials['access_token']}"

  p uri = URI("https://api.meetup.com/members/self/")
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true
  headers =
    {
      'Authorization' => bearer
    }

  p data_serialized = https.get(uri.path, headers)
  @test = JSON.parse(data_serialized)

  @events = []
  @existing_ids = []
  erb :test
end

get '/' do
  # Fetch the meetup groups
  groups = ['Machine-Learning-Tokyo',
            'Le-Wagon-Tokyo-Coding-Station',
            'tokyo-rails',
            'Women-Who-Code-Tokyo',
            'StartupTokyo',
            'Tokyo-Startup-Engineering',
            'devjapan',
            'tokyofintech']
  initialise_meetup_api

  params = { category: '1',
      city: 'London',
      country: 'GB',
      status: 'upcoming',
      format: 'json',
      page: '50'}
  meetup_api = MeetupApi.new
  @events = meetup_api.open_events(params)
  # @events = fetch_a_week_of_meetups(groups)

  # Send them to Gcal
  # service = initialize_gcal
  # @existing_ids = fetch_existing_gcal_events_ids(service)
  # post_to_gcalendar(@events, service)
  @existing_ids = []

  erb :test
end

def initialise_meetup_api
  MeetupClient.configure do |config|
    config.api_key = MEETUP_API_KEY
  end
end

def fetch_a_week_of_meetups(groups)
  events = []
  a_week_from_today = (Date.today + 7).strftime('%F')
  groups.each do |group|
    url = "https://api.meetup.com/#{group}/events?&sign=true&photo-host=public&page=20&no_later_than=#{a_week_from_today}&page=20"
    events_serialized = URI.open(url).read
    events = JSON.parse(events_serialized)
    events.each do |event|
      events << { id: event['id'],
                  group: event['group']['name'],
                  name: event['name'],
                  venue: event['venue']['name'],
                  date: Date.parse(event['local_date']),
                  url: event['link'] }
    end
  end
  events
end

# Gcal API post

OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze
APPLICATION_NAME = "Tokyo Tech Events".freeze
CREDENTIALS_PATH = "credentials.json".freeze
# The file token.yaml stores the user's access and refresh tokens, and is
# created automatically when the authorization flow completes for the first
# time.
TOKEN_PATH = "token.yaml".freeze
SCOPE = "https://www.googleapis.com/auth/calendar"

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  client_id = Google::Auth::ClientId.from_file CREDENTIALS_PATH
  token_store = Google::Auth::Stores::FileTokenStore.new file: TOKEN_PATH
  authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPE, token_store
  user_id = 'default'
  credentials = authorizer.get_credentials user_id
  if credentials.nil?
    url = authorizer.get_authorization_url base_url: OOB_URI
    puts 'Open the following URL in the browser and enter the ' \
         'resulting code after authorization:\n' + url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI
    )
  end
  credentials
end

def initialize_gcal
  # Initialize the API
  service = Google::Apis::CalendarV3::CalendarService.new
  service.client_options.application_name = APPLICATION_NAME
  service.authorization = authorize
  service
end

def fetch_existing_gcal_events_ids(service)
  ids = []
  response = service.list_events(CALENDAR_ID)
  puts "Upcoming events:"
  puts "No upcoming events found" if response.items.empty?
  response.items.each do |event|
    ids << event
  end
  ids
end

def post_to_gcalendar(events, service)
  events.each do |event|
    gcal_event = Google::Apis::CalendarV3::Event.new(
      id: event['id'],
      summary: event['name'],
      location: event['location'],
      html_link: event['url'],
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: event['date'].strftime('%FT%T%:z'), # should be like'2020-03-25T17:04:00-07:00'
        time_zone: TIME_ZONE
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: event['date'].strftime('%FT%T%:z'),
        time_zone: TIME_ZONE
      )
    )

    result = service.insert_event(CALENDAR_ID, gcal_event)
    puts "Event created: #{result.html_link}"
  end
end
