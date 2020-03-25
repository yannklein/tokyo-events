require 'sinatra'
require "sinatra/json"
require 'sinatra/reloader'
require 'json'
require 'open-uri'
require "net/http"
require 'date'
require 'pry'

# Gcal gems
require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"


CALENDAR_ID = "lewagon.org_b6cap1032jp9tcdcq74v4ute58@group.calendar.google.com"

get '/test' do
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
  @events = fetch_a_week_of_meetups(groups)

  # Send them to Gcal
  service = initialize_gcal
  post_to_gcalendar(@events, service)

  erb :test
end

def fetch_a_week_of_meetups(groups)
  results = []
  a_week_from_today = (Date.today + 7).strftime('%F')
  groups.each do |group|
    url = "https://api.meetup.com/#{group}/events?&sign=true&photo-host=public&page=20&no_later_than=#{a_week_from_today}&page=20"
    events_serialized = URI.open(url).read
    events = JSON.parse(events_serialized)
    events.each do |event|
      results << { group: event['group']['name'],
                   name: event['name'],
                   venue: event['venue']['name'],
                   date: event['local_date'],
                   url: event['link'] }
    end
  end
  results
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

def fetch_existing_gcal_events_ids
  # # Fetch the next 10 events for the user
  # calendar_id = "primary"
  # response = service.list_events(CALENDAR_ID,
  #                                max_results:   10,
  #                                single_events: true,
  #                                order_by:      "startTime",
  #                                time_min:      DateTime.now.rfc3339)
  # puts "Upcoming events:"
  # puts "No upcoming events found" if response.items.empty?
  # response.items.each do |event|
  #   start = event.start.date || event.start.date_time
  #   puts "- #{event.summary} (#{start})"
  # end
end

def post_to_gcalendar(events, service)
  event = Google::Apis::CalendarV3::Event.new(
    summary: 'Google I/O 2015',
    location: '800 Howard St., San Francisco, CA 94103',
    description: 'A chance to hear more about Google\'s developer products.',
    start: Google::Apis::CalendarV3::EventDateTime.new(
      date_time: '2020-03-25T09:00:00-07:00',
      time_zone: 'America/Los_Angeles'
    ),
    end: Google::Apis::CalendarV3::EventDateTime.new(
      date_time: '2020-03-25T17:04:00-07:00',
      time_zone: 'America/Los_Angeles'
    )
  )

  result = service.insert_event(CALENDAR_ID, event)
  puts "Event created: #{result.html_link}"
end
