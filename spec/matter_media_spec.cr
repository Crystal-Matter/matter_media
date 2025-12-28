require "./spec_helper"

describe MatterMedia do
  it "has a version" do
    MatterMedia::VERSION.should be_a(String)
    MatterMedia::VERSION.should_not be_empty
  end
end
