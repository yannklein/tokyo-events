require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

desc 'Look for style guide offenses in your code'
task :rubocop do
  sh 'rubocop --format simple || true'
end

task default: [:rubocop, :spec]

desc 'Open an irb session preloaded with the environment'
task :console do
  require 'rubygems'
  require 'pry'

  Pry.start
end

desc 'Fetch all the meetup events and send them to Gcal'
task :fetch_event do
  require_relative "app"
  fetch_event
end
