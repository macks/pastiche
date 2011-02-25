require 'spec_helper'

describe 'Pastiche' do

  include Webrat::Methods
  include Webrat::Matchers
  include Rack::Test::Methods

  before do
    Pastiche.set :environment, :test
    Pastiche.use Rack::Session::Cookie
  end

  before :each do
    DataMapper.auto_migrate!
  end

  def app
    Pastiche
  end

  it 'returns top page at /' do
    visit '/'
    last_response.should be_ok
    last_response.body.should have_selector('title', :content => 'Pastiche')
  end

  it 'returns login form at /login' do
    visit '/login'
    last_response.should be_ok
    last_response.body.should have_selector('form')
    last_response.body.should have_selector('input', :class => 'openid-identifier')
  end

  it 'returns a snippet at /ID' do
    login
    snippet = @user.snippets.create(
      :filename    => 'Filename.txt',
      :type        => 'plain_text',
      :description => 'Snippet description',
      :text        => 'Snippet body'
    )
    visit "/#{snippet.id}"
    last_response.should be_ok
    last_response.should have_selector('pre', :content => 'Snippet body')
    last_response.should contain('Filename.txt')
    last_response.should contain('Snippet description')
  end

  it 'creates a new snippet when posted at /new' do
    login
    click_link 'New snippet'
    fill_in 'filename',    :with => 'NewFile.txt'
    fill_in 'description', :with => 'New description'
    fill_in 'text',        :with => 'New snippet body'
    select  'plain text', :from => 'type'
    select  /8/,          :from => 'tabstop'
    click_button 'Create'

    follow_redirect!
    last_response.should be_ok
    last_request.path.should match(%r{^/\d+$})
    last_response.should contain('New snippet body')
  end

  it 'returns a login form when unauthorized user is at /new' do
    visit '/new'
    follow_redirect!
    last_request.path.should == '/login'
  end

  it 'occurs 403 error when unauthorized user try to post' do
    visit '/new', :post, :filename => 'filename.ext', :type => 'plain_text', :description => '', :text => 'text'
    last_response.should_not be_ok
    last_response.status.should == 403
  end

  it 'returns user page at /user/NAME' do
    login
    visit "/user/#{@user.nickname}"
    last_response.should be_ok
    last_response.should contain(@user.fullname)

    click_link 'Logout'
    visit "/user/#{@user.nickname}"
    last_response.should be_ok
    last_response.should contain(@user.fullname)
  end

  it 'clears user session at /logout' do
    login
    click_link 'Logout'
    follow_redirect!
    last_request.path.should == '/'
    last_response.should have_selector('div', :content => 'Logged out')
    last_response.should have_selector('a', :content => 'login')
  end

  #
  # helper methods
  #

  def login(id = rand(1000))
    openid = 'http://openid.example.com/user%03d' % id
    @user = Pastiche::User.create(:openid => openid, :nickname => "user#{id}", :fullname => "John Smith #{id}")
    visit "/login/#{@user.id}"
    follow_redirect!
    last_response.should contain('logged in as')
  end

end
