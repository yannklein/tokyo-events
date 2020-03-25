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


CALENDAR_ID = "lewagon.org_i5sv5pnr5htimao32tkb9a4jko@group.calendar.google.com"
TIME_ZONE = "Asia/Tokyo"

get '/' do
  # Fetch the meetup groups
  @groups = ['Machine-Learning-Tokyo',
            'Le-Wagon-Tokyo-Coding-Station',
            'tokyo-rails',
            'Women-Who-Code-Tokyo',
            'StartupTokyo',
            'Tokyo-Startup-Engineering',
            'devjapan',
            'tokyofintech']
  @events = fetch_two_month_of_meetups(groups)

  # Send them to Gcal
  service = initialize_gcal
  @existing_ids = fetch_existing_gcal_events_ids(service)
  post_to_gcalendar(@events, service, @existing_ids)

  erb :test
end

def fetch_two_month_of_meetups(groups)
  meetup_events = []
  a_week_from_today = (Date.today + 60).strftime('%F')
  groups.each do |group|
    url = "https://api.meetup.com/#{group}/events?&sign=true&photo-host=public&page=20&no_later_than=#{a_week_from_today}&page=20"
    events_serialized = URI.open(url).read
    events = JSON.parse(events_serialized)
    puts "Raw events data"
    p events
    events.each do |event|
      meetup_events << { id: event['id'],
                  group: event['group']['name'],
                  name: "@#{event['local_time']} | #{event['name']}",
                  venue: event['venue'].nil? ? "" : event['venue']['name'],
                  date: event['local_date'],
                  url: event['link'] || "",
                  description: "<p><a href='#{event['link']}'>Open the event page</a></p>#{event['description']}" || "" }
    end
  end
  meetup_events
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
    ids << event.id
  end
  ids
end

def post_to_gcalendar(events, service, existing_ids)
  # Create new events
  events.reject { |event| existing_ids.include?(event[:id]) }.each do |event|
    puts "Event to be created:"
    p event
    gcal_event = Google::Apis::CalendarV3::Event.new(
      id: event[:id],
      summary: event[:name],
      location: event[:location],
      description: event[:description],
      html_link: event[:url],
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date: event[:date], # should be like2020-03-25T17:04:00-07:00
        time_zone: TIME_ZONE
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date: event[:date],
        time_zone: TIME_ZONE
      )
    )

    result = service.insert_event(CALENDAR_ID, gcal_event)
    puts "Event created: #{result.html_link}"
  end

  # Update existing ones
  events.select { |event| existing_ids.include?(event[:id]) }.each do |event|
    old_gcal_event = service.get_event(CALENDAR_ID, event[:id])
    puts "Event to be modified:"
    p event
    gcal_event = Google::Apis::CalendarV3::Event.new(
      id: event[:id],
      summary: event[:name],
      location: event[:location],
      description: event[:description],
      html_link: event[:url],
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date: event[:date], # should be like2020-03-25T17:04:00-07:00
        time_zone: TIME_ZONE
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date: event[:date],
        time_zone: TIME_ZONE
      )
    )

    result = service.update_event(CALENDAR_ID, old_gcal_event.id, gcal_event)
    print "Event modified:#{result.updated}"
  end
end
