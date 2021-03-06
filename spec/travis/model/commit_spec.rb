require 'spec_helper'

describe Commit do
  include Support::ActiveRecord

  let(:commit) { Commit.new(:commit => '12345678') }

  describe 'config_url' do
    it 'returns the raw url to the .travis.yml file on github' do
      commit.repository = Repository.new(:owner_name => 'travis-ci', :name => 'travis-ci')
      commit.config_url.should == 'https://raw.github.com/travis-ci/travis-ci/12345678/.travis.yml'
    end
  end

  describe 'pull_request?' do
    it 'is false for a nil ref' do
      commit.ref = nil
      commit.pull_request?.should be_false
    end

    it 'is false for a ref named ref/branch/master' do
      commit.ref = 'refs/branch/master'
      commit.pull_request?.should be_false
    end

    it 'is false for a ref named ref/pull/180/head' do
      commit.ref = 'refs/pull/180/head'
      commit.pull_request?.should be_false
    end

    it 'is true for a ref named ref/pull/180/merge' do
      commit.ref = 'refs/pull/180/merge'
      commit.pull_request?.should be_true
    end
  end
end
