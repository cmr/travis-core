require 'spec_helper'

describe Travis::Github::Sync::Repositories do
  include Travis::Testing::Stubs

  let(:public_repo)  { stub_repository(:slug => 'sven/public')  }
  let(:private_repo) { stub_repository(:slug => 'sven/private') }
  let(:removed_repo) { stub_repository(:slug => 'sven/removed') }

  let(:user) { stub_user(:organizations => [org], :github_oauth_token => 'token', :repositories => [public_repo, removed_repo]) }
  let(:org)  { stub('org', :login => 'the-org') }
  let(:sync) { Travis::Github::Sync::Repositories.new(user) }

  let(:repos) { [
    { 'name' => 'public',  'owner' => { 'login' => 'sven' }, 'permissions' => { 'admin' => true }, 'private' => false },
    { 'name' => 'private', 'owner' => { 'login' => 'sven' }, 'permissions' => { 'admin' => true }, 'private' => true }
  ] }

  before :each do
    GH.stubs(:[]).returns(repos)
    Travis::Github::Sync::Repository.stubs(:new).returns(stub('repo', :run => public_repo))
    Travis::Github::Sync::Repository.stubs(:unpermit_all)
    @type = Travis::Github::Sync::Repositories.type
  end

  after :each do
    Travis::Github::Sync::Repositories.type = @type
  end

  it "fetches the user's repositories" do
    GH.expects(:[]).with('user/repos') # should be: ?type=public
    sync.run
  end

  it "fetches the user's orgs' repositories" do
    GH.expects(:[]).with('orgs/the-org/repos') # should be: ?type=public
    sync.run
  end

  describe 'given type is set to public' do
    before :each do
      Travis::Github::Sync::Repositories.type = 'public'
    end

    it 'synchronizes each of the public repositories' do
      Travis::Github::Sync::Repository.expects(:new).with(user, repos.first).once.returns(stub('repo', :run => public_repo))
      sync.run
    end

    it 'does not synchronize private repositories' do
      Travis::Github::Sync::Repository.expects(:new).with(user, repos.last).never
      sync.run
    end
  end

  describe 'given type is set to private' do
    before :each do
      Travis::Github::Sync::Repositories.type = 'private'
    end

    it 'synchronizes each of the private repositories' do
      Travis::Github::Sync::Repository.expects(:new).with(user, repos.last).once.returns(stub('repo', :run => private_repo))
      sync.run
    end

    it 'does not synchronize public repositories' do
      Travis::Github::Sync::Repository.expects(:new).with(user, repos.first).never
      sync.run
    end
  end

  it "removes repositories from the user's permissions which are not listed in the data from Github" do
    Travis::Github::Sync::Repository.expects(:unpermit_all).with(user, [removed_repo])
    sync.run
  end
end
