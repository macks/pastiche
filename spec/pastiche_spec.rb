require 'pastiche'
require 'spec_helper'

describe 'Pastiche' do

  include Webrat::Methods
  include Webrat::Matchers
  include Rack::Test::Methods

  before do
    Pastiche.set :environment, :test
  end

  before :each do
    DataMapper.auto_migrate!
  end

  def app
    Pastiche
  end

  it 'returns top page' do
    visit '/'
    last_response.should be_ok
    last_response.body.should have_selector('title', :content => 'Pastiche')
  end

  it 'returns login form' do
    visit '/login'
    last_response.should be_ok
    last_response.body.should have_selector('form')
    last_response.body.should have_selector('input', :class => 'openid_identifier')
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
