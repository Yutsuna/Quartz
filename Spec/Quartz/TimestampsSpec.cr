require "../SpecHelper"

describe "timestamps" do
  before_each { quartz_spec_reset }

  describe "on an unsaved record" do
    it "leaves created_at and updated_at nil" do
      record = FSpecStamped.new(title: "Hi")
      record.created_at.should be_nil
      record.updated_at.should be_nil
    end
  end

  describe "on create" do
    it "sets created_at and updated_at to the same instant" do
      record = FSpecStamped.objects.create(title: "Hi")
      record.created_at.should_not be_nil
      record.updated_at.should_not be_nil
      record.created_at.should eq(record.updated_at)
    end

    it "exposes both timestamps through to_h" do
      record = FSpecStamped.objects.create(title: "Hi")
      record.to_h.has_key?("created_at").should be_true
      record.to_h.has_key?("updated_at").should be_true
    end
  end

  describe "on update" do
    it "advances updated_at but leaves created_at untouched" do
      record = FSpecStamped.objects.create(title: "Hi")
      created = record.created_at

      sleep 1.millisecond
      record.title = "Bye"
      record.save!

      record.created_at.should eq(created)
      record.updated_at.not_nil!.should be > record.created_at.not_nil!
    end
  end
end
