require 'spec_helper'

describe Travis::Task::Irc do
  include Support::ActiveRecord
  include Travis::Testing::Stubs

  let(:tcp) { stub('tcp', :eof? => true, :close => true) }
  let(:seq) { sequence('tcp') }
  let(:channels) { { ['irc.freenode.net', 1234] => ['travis'] } }

  before do
    Travis.config.notifications = [:irc]
    Travis::Features.stubs(:active?).returns(true)
    Repository.stubs(:find).returns(stub('repo'))
    Url.stubs(:shorten).returns(url)
  end

  def expect_irc(host, port, channel, messages)
    TCPSocket.expects(:open).with(host, port).in_sequence(seq).returns(tcp)
    messages.each { |message| tcp.expects(:puts).with(message).in_sequence(seq) }
  end

  def run(build, channels = nil)
    data = Travis::Api.data(build, :for => 'event', :version => 'v2')
    Travis::Task.run(:irc, data, :channels => channels || self.channels, true)
  end

  let(:simple_irc_notfication_messages) do
    [
      'NICK travis-ci',
      'USER travis-ci travis-ci travis-ci :travis-ci',
      'JOIN #travis',
      'PRIVMSG #travis :[travis-ci] svenfuchs/minimal#2 (master - 62aae5f : Sven Fuchs): The build passed.',
      'PRIVMSG #travis :[travis-ci] Change view : http://trvs.io/short',
      'PRIVMSG #travis :[travis-ci] Build details : http://trvs.io/short',
      'PART #travis',
      'QUIT'
    ]
  end

  it "one irc notification" do
    expect_irc 'irc.freenode.net', 1234, 'travis', simple_irc_notfication_messages
    run(build)
  end

  it "one irc notification using notice" do
    build.obfuscated_config[:notifications] = { :irc => { :use_notice => true } }

    expect_irc 'irc.freenode.net', 1234, 'travis', [
      'NICK travis-ci',
      'USER travis-ci travis-ci travis-ci :travis-ci',
      'JOIN #travis',
      'NOTICE #travis :[travis-ci] svenfuchs/minimal#2 (master - 62aae5f : Sven Fuchs): The build passed.',
      'NOTICE #travis :[travis-ci] Change view : http://trvs.io/short',
      'NOTICE #travis :[travis-ci] Build details : http://trvs.io/short',
      'PART #travis',
      'QUIT'
    ]
    run(build)
  end

  it "one irc notification without joining the channel" do
    build.obfuscated_config[:notifications] = { :irc => { :skip_join => true } }

    expect_irc 'irc.freenode.net', 1234, 'travis', [
      'NICK travis-ci',
      'USER travis-ci travis-ci travis-ci :travis-ci',
      'PRIVMSG #travis :[travis-ci] svenfuchs/minimal#2 (master - 62aae5f : Sven Fuchs): The build passed.',
      'PRIVMSG #travis :[travis-ci] Change view : http://trvs.io/short',
      'PRIVMSG #travis :[travis-ci] Build details : http://trvs.io/short',
      'QUIT'
    ]
    run(build)
  end

  it 'with a custom message template' do
    build.obfuscated_config[:notifications] = { :irc => { :template => '%{repository} %{commit}' } }

    expect_irc 'irc.freenode.net', 1234, 'travis', [
      'NICK travis-ci',
      'USER travis-ci travis-ci travis-ci :travis-ci',
      'JOIN #travis',
      'PRIVMSG #travis :[travis-ci] svenfuchs/minimal 62aae5f',
      'PART #travis',
      'QUIT'
    ]
    run(build)
  end

  it 'with multiple custom message templates' do
    build.obfuscated_config[:notifications] = { :irc => { :template => ['%{repository} %{commit}', '%{message}'] } }

    expect_irc 'irc.freenode.net', 1234, 'travis', [
      'NICK travis-ci',
      'USER travis-ci travis-ci travis-ci :travis-ci',
      'JOIN #travis',
      'PRIVMSG #travis :[travis-ci] svenfuchs/minimal 62aae5f',
      'PRIVMSG #travis :[travis-ci] The build passed.',
      'PART #travis',
      'QUIT'
    ]
    run(build)
  end

  it 'with two irc notifications to different hosts' do
    [['irc.freenode.net', 1234, 'travis'], ['irc.example.com', 6667, 'example']].each do |host, port, channel|
      expect_irc host, port, channel, [
        'NICK travis-ci',
        'USER travis-ci travis-ci travis-ci :travis-ci',
        "JOIN ##{channel}",
        "PRIVMSG ##{channel} :[travis-ci] svenfuchs/minimal#2 (master - 62aae5f : Sven Fuchs): The build passed.",
        "PRIVMSG ##{channel} :[travis-ci] Change view : http://trvs.io/short",
        "PRIVMSG ##{channel} :[travis-ci] Build details : http://trvs.io/short",
        "PART ##{channel}",
        'QUIT'
      ]
    end
    run(build, ['irc.freenode.net', 1234] => ['travis'], ['irc.example.com', 6667] => ['example'])
  end

  it 'does not disconnect for notifications to channels on the same host' do
    expect_irc 'irc.freenode.net', 6667, 'travis', [
      'NICK travis-ci',
      'USER travis-ci travis-ci travis-ci :travis-ci',
      'JOIN #travis',
      'PRIVMSG #travis :[travis-ci] svenfuchs/minimal#2 (master - 62aae5f : Sven Fuchs): The build passed.',
      'PRIVMSG #travis :[travis-ci] Change view : http://trvs.io/short',
      'PRIVMSG #travis :[travis-ci] Build details : http://trvs.io/short',
      'PART #travis',
      'JOIN #example',
      'PRIVMSG #example :[travis-ci] svenfuchs/minimal#2 (master - 62aae5f : Sven Fuchs): The build passed.',
      'PRIVMSG #example :[travis-ci] Change view : http://trvs.io/short',
      'PRIVMSG #example :[travis-ci] Build details : http://trvs.io/short',
      'PART #example',
      'QUIT'
    ]
    run(build, ['irc.freenode.net', 6667] => ['travis', 'example'])
  end

  context 'when configured to IRC+SSL server' do
    it "should wrap socket with ssl (in client private)" do
      Travis::Task::Irc::Client.expects(:wrap_ssl).with(tcp).returns(tcp)

      expect_irc 'irc.freenode.net', 1234, 'travis', simple_irc_notfication_messages
      run(build, ['irc.freenode.net', 1234, :ssl] => ['travis'])
    end
  end

end
