require 'spec_helper'

describe StatusPage::Services::Base do
  let(:request) { ActionController::TestRequest.create }

  subject { described_class.new(request: request) }

  describe '#initialize' do
    it 'sets the request' do
      expect(described_class.new(request: request).request).to eq(request)
    end
  end

  describe '#service_name' do
    it { expect(described_class.service_name).to eq('base') }
  end

  describe '#check!' do
    it 'abstract' do
      expect {
        subject.check!
      }.to raise_error(NotImplementedError)
    end
  end

  describe '#configurable?' do
    it { expect(described_class).not_to be_configurable }
  end

  describe '#configuration_class' do
    it 'abstract' do
      expect(described_class.send(:configuration_class)).to be_nil
    end
  end
end
