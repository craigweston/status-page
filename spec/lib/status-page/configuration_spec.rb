require 'spec_helper'

describe StatusPage::Configuration do
  describe 'defaults' do
    it { expect(subject.providers).to eq(Set.new([])) }
    it { expect(subject.error_callback).to be_nil }
    it { expect(subject.basic_auth_credentials).to be_nil }
  end

  describe 'providers' do
    StatusPage::Configuration::PROVIDERS.each do |service_name|
      before do
        subject.instance_variable_set('@providers', Set.new)

        stub_const("StatusPage::Services::#{service_name.capitalize}", Class.new)
      end

      it "responds to #{service_name}" do
        expect(subject).to respond_to(service_name)
      end

      it "configures #{service_name}" do
        expect {
          subject.send(service_name)
        }.to change { subject.providers }.to(Set.new(["StatusPage::Services::#{service_name.capitalize}".constantize]))
      end

      it "returns #{service_name}'s class" do
        expect(subject.send(service_name)).to eq("StatusPage::Services::#{service_name.capitalize}".constantize)
      end
    end
  end

  describe '#add_custom_service' do
    before do
      subject.instance_variable_set('@providers', Set.new)
    end

    context 'inherits' do
      class CustomProvider < StatusPage::Services::Base
      end

      it 'accepts' do
        expect {
          subject.add_custom_service(CustomProvider)
        }.to change { subject.providers }.to(Set.new([CustomProvider]))
      end

      it 'returns CustomProvider class' do
        expect(subject.add_custom_service(CustomProvider)).to eq(CustomProvider)
      end
    end

    context 'does not inherit' do
      class TestClass
      end

      it 'does not accept' do
        expect {
          subject.add_custom_service(TestClass)
        }.to raise_error(ArgumentError)
      end
    end
  end
end
