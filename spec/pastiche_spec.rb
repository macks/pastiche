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
      :filename => 'Filename.txt',
      :type     => 'plain_text',
      :comment  => 'Snippet comment',
      :text     => 'Snippet body'
    )
    visit "/#{snippet.id}"
    last_response.should be_ok
    last_response.should have_selector('pre', :content => 'Snippet body')
    last_response.should contain('Filename.txt')
    last_response.should contain('Snippet comment')
  end

  it 'creates a new snippet when posted at /new' do
    login
    click_link 'New snippet'
    fill_in 'filename', :with => 'NewFile.txt'
    fill_in 'comment',  :with => 'New comment'
    fill_in 'text',     :with => 'New snippet body'
    select  'plain text', :from => 'type'
    click_button 'Create'

    last_response.should be_ok
    current_url.should =~ %r{^/\d+$}
    last_response.should contain('New snippet body')
  end

  it 'returns a login form when unauthorized user is at /new' do
    visit '/new'
    current_url.should == '/login'
  end

  it 'occurs 403 error when unauthorized user try to post' do
    visit '/new', :post, :filename => 'filename.ext', :type => 'plain_text', :comment => '', :text => 'text'
    last_response.should_not be_ok
    last_response.status.should == 403
  end

  it 'returns user page at /user/NAME' do
    login
    visit "/user/#{@user.nickname}"
    last_response.should be_ok
    last_response.should contain('Profile')
    last_response.should contain(@user.openid)

    click_link 'Logout'
    visit "/user/#{@user.nickname}"
    last_response.should be_ok
    last_response.should contain('Profile')
    last_response.should contain(@user.openid)
  end

  it 'clears user session at /logout' do
    login
    click_link 'Logout'
    current_url.should == '/'
    last_response.should have_selector('div', :content => 'Logged out')
    last_response.should have_selector('a', :content => 'login')
  end

  #
  # helper methods
  #

  def login(id = rand(1000))
    openid = 'http://openid.example.com/user%03d' % id
    @user = Pastiche::User.create(:openid => openid, :nickname => "user#{id}")
    visit "/login/#{@user.id}"
    last_response.should contain('logged in as')
  end

end
