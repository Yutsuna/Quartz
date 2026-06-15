require "../SpecHelper"

describe "lifecycle callbacks" do
  before_each { quartz_spec_reset }

  describe "on create" do
    it "fires before_save → before_create → after_create → after_save in order" do
      record = FSpecHooked.objects.create(name: "Léo")
      record.trace.should eq(["before_save", "before_create", "after_create", "after_save"])
    end

    it "fires the same chain for an instance saved by hand" do
      record = FSpecHooked.new(name: "Léo")
      record.save!
      record.trace.should eq(["before_save", "before_create", "after_create", "after_save"])
    end
  end

  describe "on update" do
    it "fires only the save hooks, not the create hooks" do
      record = FSpecHooked.objects.create(name: "Léo")
      record.trace.clear
      record.name = "Zoé"
      record.save!
      record.trace.should eq(["before_save", "after_save"])
    end
  end

  describe "on delete" do
    it "fires before_delete then after_delete and unpersists the record" do
      record = FSpecHooked.objects.create(name: "Léo")
      record.trace.clear
      record.delete.should be_true
      record.trace.should eq(["before_delete", "after_delete"])
      record.persisted?.should be_false
    end

    it "skips after_delete when nothing was removed" do
      record = FSpecHooked.new(name: "Léo")
      record.delete.should be_false
      record.trace.should eq(["before_delete"])
    end
  end

  describe "field mutation" do
    it "persists a change made in before_save" do
      record = FSpecNormalized.objects.create(name: "  Léo  ")
      record.name.should eq("léo")
      FSpecNormalized.objects.find(record.id).name.should eq("léo")
    end
  end

  describe "inheritance" do
    it "runs ancestor and own callbacks via the super chain, in order" do
      record = FSpecHookedChild.objects.create(name: "Léo")
      record.trace.should eq([
        "before_save", "child_before_save",
        "before_create", "after_create", "after_save",
      ])
    end
  end
end
