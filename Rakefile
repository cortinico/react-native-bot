$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require 'bot'
require 'dotenv/tasks'

task :runDaily => :dotenv do
  Bot.runDaily
end

task :runHourly => :dotenv do
  Bot.runHourly
end

task :runFrequently => :dotenv do
  Bot.runFrequently
end
