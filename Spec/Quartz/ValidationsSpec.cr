require "../SpecHelper"

describe "Quartz validations" do
  before_each { quartz_spec_reset }

  describe Quartz::Errors do
    it "collects messages per field" do
      errors = Quartz::Errors.new
      errors.empty?.should be_true
      errors.add("email", "can't be blank")
      errors.add("email", "is invalid")
      errors.empty?.should be_false
      errors["email"].should eq(["can't be blank", "is invalid"])
      errors["missing"].should be_empty
      errors.full_messages.should eq(["email can't be blank", "email is invalid"])
    end
  end

  describe "presence" do
    it "fails on a blank string" do
      account = FSpecAccount.new(email: "", nickname: "leo", age: 20)
      account.valid?.should be_false
      account.errors["email"].should eq(["can't be blank"])
    end

    it "fails on a whitespace-only string" do
      FSpecAccount.new(email: "   ", nickname: "leo", age: 20).valid?.should be_false
    end

    it "passes on a present value" do
      FSpecAccount.new(email: "x@y.z", nickname: "leo", age: 20).errors["email"].should be_empty
    end
  end

  describe "length" do
    it "fails below the minimum" do
      FSpecAccount.new(email: "x@y.z", nickname: "a", age: 20).errors["nickname"]
        .should eq(["is too short (minimum 2 characters)"])
    end

    it "fails above the maximum" do
      FSpecAccount.new(email: "x@y.z", nickname: "abcdefghijk", age: 20).errors["nickname"]
        .should eq(["is too long (maximum 10 characters)"])
    end

    it "passes inside the range" do
      FSpecAccount.new(email: "x@y.z", nickname: "leo", age: 20).errors["nickname"].should be_empty
    end
  end

  describe "custom validate block" do
    it "runs and records against the chosen key" do
      FSpecAccount.new(email: "x@y.z", nickname: "leo", age: 12).errors["age"]
        .should eq(["must be adult"])
    end

    it "passes when the condition is not met" do
      FSpecAccount.new(email: "x@y.z", nickname: "leo", age: 20).errors["age"].should be_empty
    end
  end

  describe "#valid?" do
    it "reflects the current field values on each call" do
      account = FSpecAccount.new(email: "", nickname: "leo", age: 20)
      account.valid?.should be_false
      account.email = "x@y.z"
      account.valid?.should be_true
    end

    it "aggregates every failure in full_messages" do
      FSpecAccount.new(email: "", nickname: "a", age: 12).errors.full_messages.should eq([
        "email can't be blank",
        "nickname is too short (minimum 2 characters)",
        "age must be adult",
      ])
    end
  end

  describe "#save!" do
    it "raises EValidation carrying the errors when invalid" do
      account = FSpecAccount.new(email: "", nickname: "leo", age: 20)
      ex = expect_raises(Quartz::EValidation) { account.save! }
      ex.errors["email"].should eq(["can't be blank"])
      account.persisted?.should be_false
    end

    it "persists and returns self when valid" do
      account = FSpecAccount.new(email: "x@y.z", nickname: "leo", age: 20)
      account.save!.should be(account)
      account.persisted?.should be_true
      FSpecAccount.objects.find(account.id).should eq(account)
    end
  end

  describe "#save" do
    it "returns false without persisting when invalid" do
      account = FSpecAccount.new(email: "", nickname: "leo", age: 20)
      account.save.should be_false
      account.persisted?.should be_false
      FSpecAccount.objects.count.should eq(0)
    end

    it "returns true and persists when valid" do
      account = FSpecAccount.new(email: "x@y.z", nickname: "leo", age: 20)
      account.save.should be_true
      account.persisted?.should be_true
      FSpecAccount.objects.find(account.id).should eq(account)
    end
  end

  describe "FManager#create" do
    it "raises EValidation without persisting when invalid" do
      ex = expect_raises(Quartz::EValidation) do
        FSpecAccount.objects.create(email: "", nickname: "leo", age: 20)
      end
      ex.errors["email"].should eq(["can't be blank"])
      FSpecAccount.objects.count.should eq(0)
    end

    it "persists and returns the record when valid" do
      account = FSpecAccount.objects.create(email: "x@y.z", nickname: "leo", age: 20)
      account.persisted?.should be_true
      FSpecAccount.objects.find(account.id).should eq(account)
    end
  end

  describe "inheritance" do
    it "runs both inherited and own validations" do
      account = FSpecPremiumAccount.new(email: "", nickname: "leo", age: 20, referral: "")
      account.valid?.should be_false
      account.errors["email"].should eq(["can't be blank"])
      account.errors["referral"].should eq(["can't be blank"])
    end

    it "passes when every inherited and own rule is satisfied" do
      FSpecPremiumAccount.new(email: "x@y.z", nickname: "leo", age: 20, referral: "abc")
        .valid?.should be_true
    end
  end

  describe "model without validations" do
    it "is always valid and save! persists" do
      user = FSpecUser.new(name: "Léo")
      user.valid?.should be_true
      user.save!.should be(user)
      user.persisted?.should be_true
    end
  end

end
