require 'sinatra'
require "sinatra/json"
require 'sinatra/reloader'
require 'json'
require 'open-uri'
require "net/http"
require 'date'
require 'pry'
require 'google/apis/calendar_v3'

CALENDAR_ID = "lewagon.org_b6cap1032jp9tcdcq74v4ute58@group.calendar.google.com"

get '/test' do
end

get '/' do
  groups = ['Machine-Learning-Tokyo',
            'Le-Wagon-Tokyo-Coding-Station',
            'tokyo-rails',
            'Women-Who-Code-Tokyo',
            'StartupTokyo',
            'Tokyo-Startup-Engineering',
            'devjapan',
            'tokyofintech']
  @results = fetch_a_week_of_meetups(groups)
  erb :test
end

def fetch_a_week_of_meetups(groups)
  results = []
  a_week_from_today = (Date.today + 7).strftime('%F')
  groups.each do |group|
    url = "https://api.meetup.com/#{group}/events?&sign=true&photo-host=public&page=20&no_later_than=#{a_week_from_today}&page=20"
    events_serialized = open(url).read
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

def post_to_gcalendar(events)
  # uri = URI.parse("https://www.googleapis.com/calendar/v3/calendars/#{CALENDAR_ID}/events")
  # response = Net::HTTP.post_form(uri, {"q" => "My query", "per_page" => "50"})


  # event = Google::Apis::CalendarV3::Event.new(
  #   summary: 'Google I/O 2015',
  #   location: '800 Howard St., San Francisco, CA 94103',
  #   description: 'A chance to hear more about Google\'s developer products.',
  #   start: Google::Apis::CalendarV3::EventDateTime.new(
  #     date_time: '2015-05-28T09:00:00-07:00',
  #     time_zone: 'America/Los_Angeles'
  #   ),
  #   end: Google::Apis::CalendarV3::EventDateTime.new(
  #     date_time: '2015-05-28T17:00:00-07:00',
  #     time_zone: 'America/Los_Angeles'
  #   )
  # )

  # result = client.insert_event('primary', event)
  # puts "Event created: #{result.html_link}"
end
