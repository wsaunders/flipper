require 'helper'

RSpec.describe Flipper::Gate do
  let(:feature_name) { :stats }

  subject {
    described_class.new
  }

  describe "#inspect" do
    context "for subclass" do
      let(:subclass) {
        Class.new(described_class) {
          def name
            :name
          end

          def key
            :key
          end

          def data_type
            :set
          end
        }
      }

      subject {
        subclass.new
      }

      it "includes attributes" do
        string = subject.inspect
        expect(string).to include(subject.object_id.to_s)
        expect(string).to include('name=:name')
        expect(string).to include('key=:key')
        expect(string).to include('data_type=:set')
      end
    end
  end

  describe "activation" do
    let(:subclass) {
      Class.new(described_class) {
        def name
          :name
        end

        def key
          :key
        end

        def data_type
          :set
        end
      }
    }

    it "is activated by default" do
      instance = subclass.new
      expect(instance.activated?).to be(true)
    end

    it "can be deactivated and reactivated" do
      instance = subclass.new
      instance.deactivate
      expect(instance.activated?).to be(false)
      expect(instance.deactivated?).to be(true)
      instance.activate
      expect(instance.activated?).to be(true)
      expect(instance.deactivated?).to be(false)
    end
  end
end
