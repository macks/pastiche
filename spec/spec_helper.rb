require 'rubygems'
require 'spec'
require 'webrat'
require 'webrat/sinatra'

ENV['RACK_ENV'] = 'test'

Webrat.configure do |config|
  config.mode = :rack
end

require 'pastiche'

DataMapper.setup(:default, 'sqlite3::memory:')
