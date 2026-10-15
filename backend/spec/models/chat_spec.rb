require "rails_helper"

RSpec.describe Chat do
  it "persists instructions using the migrated model registry and UUID references" do
    model = RubyLLM::ActiveRecord::Model.create!(model_id: "gpt-4o-mini", name: "GPT-4o mini", provider: "openai")
    chat = described_class.create!(model: model)

    chat.with_instructions("Suggest tags for saved links")

    expect(chat.reload.model.id).to eq(model.id)
    expect(chat.model_id).to eq("gpt-4o-mini")
    expect(chat.messages.last.content).to eq("Suggest tags for saved links")
    expect(chat.messages.last.to_llm.role).to eq(:system)
    expect(chat.id).to match(/\A[0-9a-f-]{14}7/)
  end
end
