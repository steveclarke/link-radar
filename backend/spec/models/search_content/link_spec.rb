# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchContent::Link, type: :model do
  let(:link) { build(:link) }
  let(:builder) { described_class.new(link) }

  it "responds to required class methods" do
    expect(described_class).to respond_to(:search_fields, :using)
  end

  it "builds projection for valid link" do
    expect(builder.search_projection).to be_a(String)
  end
end
