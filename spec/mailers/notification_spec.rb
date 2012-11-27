require "spec_helper"

describe Notification do
  describe "new_campaign" do
    let(:mail) { Notification.new_campaign }

    it "renders the headers" do
      mail.subject.should eq("New campaign")
      mail.to.should eq(["to@example.org"])
      mail.from.should eq(["from@example.com"])
    end

    it "renders the body" do
      mail.body.encoded.should match("Hi")
    end
  end

end
