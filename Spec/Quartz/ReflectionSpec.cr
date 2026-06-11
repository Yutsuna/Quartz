require "../SpecHelper"

describe Quartz do
  describe ".models" do
    it "lists every concrete model class" do
      Quartz.models.should contain(FSpecUser)
      Quartz.models.should contain(FSpecPost)
    end

    it "excludes abstract models but includes their concrete children" do
      Quartz.models.should_not contain(FSpecTimestamped)
      Quartz.models.should contain(FSpecArticle)
    end

    it "returns a stable Array(Quartz::AModel.class)" do
      Quartz.models.should be_a(Array(Quartz::AModel.class))
    end
  end

  describe ".model_names" do
    it "lists every concrete model class name" do
      Quartz.model_names.should contain("FSpecUser")
      Quartz.model_names.should contain("FSpecAdmin")
      Quartz.model_names.should_not contain("FSpecTimestamped")
    end
  end
end
