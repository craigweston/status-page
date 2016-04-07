require 'spec_helper'

describe StatusPage do
  let(:time) { Time.local(1990) }

  before do
    StatusPage.configuration = StatusPage::Configuration.new

    allow(StatusPage.configuration).to receive(:interval).and_return(0)

    Timecop.freeze(time)
  end

  let(:request) { ActionController::TestRequest.create }

  after do
    Timecop.return
  end

  describe '#configure' do
    describe 'providers' do
      it 'configures a single provider' do
        expect {
          subject.configure do |config|
            config.use :redis
          end
        }.to change { StatusPage.configuration.providers }
          .to(Set.new([StatusPage::Services::Redis]))
      end

      it 'configures a multiple providers' do
        expect {
          subject.configure do |config|
            config.use :redis
            config.use :sidekiq
          end
        }.to change { StatusPage.configuration.providers }
          .to(Set.new([StatusPage::Services::Redis, StatusPage::Services::Sidekiq]))
      end

      it 'appends new providers' do
        expect {
          subject.configure do |config|
            config.use :resque
          end
        }.to change { StatusPage.configuration.providers }.to(
          Set.new([StatusPage::Services::Resque]))
      end
    end

    describe 'error_callback' do
      it 'configures' do
        error_callback = proc {}

        expect {
          subject.configure do |config|
            config.error_callback = error_callback
          end
        }.to change { StatusPage.configuration.error_callback }.to(error_callback)
      end
    end

    describe 'basic_auth_credentials' do
      it 'configures' do
        expected = {
          username: 'username',
          password: 'password'
        }

        expect {
          subject.configure do |config|
            config.basic_auth_credentials = expected
          end
        }.to change { StatusPage.configuration.basic_auth_credentials }.to(expected)
      end
    end
  end

  describe '#check' do
    context 'default providers' do
      it 'succesfully checks' do
        expect(subject.check(request: request)).to eq(
          :results => [],
          :status => :ok,
          :timestamp => time
        )
      end
    end

    context 'db and redis providers' do
      before do
        subject.configure do |config|
          config.use :database
          config.use :redis
        end
      end

      it 'succesfully checks' do
        expect(subject.check(request: request)).to eq(
          :results => [
            {
              name: 'database',
              message: '',
              status: 'OK'
            },
            {
              name: 'redis',
              message: '',
              status: 'OK'
            }
          ],
          :status => :ok,
          :timestamp => time
        )
      end

      context 'redis fails' do
        before do
          Services.stub_redis_failure
        end

        it 'fails check' do
          expect(subject.check(request: request)).to eq(
            :results => [
              {
                name: 'database',
                message: '',
                status: 'OK'
              },
              {
                name: 'redis',
                message: "different values (now: #{time.to_s(:db)}, fetched: false)",
                status: 'ERROR'
              }
            ],
            :status => :service_unavailable,
            :timestamp => time
          )
        end
      end

      context 'sidekiq fails' do
        it 'succesfully checks' do
          expect(subject.check(request: request)).to eq(
            :results => [
              {
                name: 'database',
                message: '',
                status: 'OK'
              },
              {
                name: 'redis',
                message: '',
                status: 'OK'
              }
            ],
            :status => :ok,
            :timestamp => time
          )
        end
      end

      context 'both redis and db fail' do
        before do
          Services.stub_database_failure
          Services.stub_redis_failure
        end

        it 'fails check' do
          expect(subject.check(request: request)).to eq(
            :results => [
              {
                name: 'database',
                message: 'Exception',
                status: 'ERROR'
              },
              {
                name: 'redis',
                message: "different values (now: #{time.to_s(:db)}, fetched: false)",
                status: 'ERROR'
              }
            ],
            :status => :service_unavailable,
            :timestamp => time
          )
        end
      end
    end

    context 'with error callback' do
      test = false

      let(:callback) do
        proc do |e|
          expect(e).to be_present
          expect(e).to be_is_a(Exception)

          test = true
        end
      end

      before do
        subject.configure do |config|
          config.use :database

          config.error_callback = callback
        end

        Services.stub_database_failure
      end

      it 'calls error_callback' do
        expect(subject.check(request: request)).to eq(
          :results => [
            {
              name: 'database',
              message: 'Exception',
              status: 'ERROR'
            }
          ],
          :status => :service_unavailable,
          :timestamp => time
        )

        expect(test).to be_truthy
      end
    end
  end
end