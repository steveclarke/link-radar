# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchContent::Tag, type: :model do
  let(:tag) { build(:tag) }
  let(:builder) { described_class.new(tag) }

  it "responds to required class methods" do
    expect(described_class).to respond_to(:search_fields, :using)
  end

  it "builds projection for valid tag" do
    expect(builder.search_projection).to be_a(String)
  end
end
