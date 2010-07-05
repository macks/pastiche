require 'rubygems'
begin
  require 'bundler'
  Bundler.setup
rescue LoadError
end

require 'spec'
require 'webrat'
require 'webrat/adapters/sinatra'

ENV['RACK_ENV'] = 'test'

Webrat.configure do |config|
  config.mode = :rack
end

require 'pastiche'

DataMapper.setup(:default, 'sqlite3::memory:')
