require 'pastiche'
require 'test/unit'
require 'rack/test'

set :environment, :test

describe 'Pastiche' do

  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  it 'returns top page' do
    get '/'
    last_response.should be_ok
    last_response.body.should == ':top'
  end

  it 'returns login form' do
    get '/login'
    last_response.should be_ok
    last_response.body.should == ':login_form'
  end

  it 'returns snippet' do
    get '/12345'
    last_response.should be_ok
    last_response.body.should == ':snippet/12345'
  end

  it 'returns user' do
    get '/user/hoge'
    last_response.should be_ok
    last_response.body.should == ':user/hoge'
  end

end
