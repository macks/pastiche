require 'rubygems'
require 'spec'
require 'webrat'
require 'webrat/sinatra'

Webrat.configure do |config|
  config.mode = :rack
end
