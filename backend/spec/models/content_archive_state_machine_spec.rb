# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentArchiveStateMachine do
  let(:content_archive) { create(:content_archive) }
  let(:state_machine) { described_class.new(content_archive, transition_class: ContentArchiveTransition, association_name: :content_archive_transitions) }

  describe "states" do
    it "defines the correct states" do
      expect(described_class.states).to eq(["pending", "processing", "completed", "failed"])
    end

    it "has pending as initial state" do
      expect(described_class.initial_state).to eq("pending")
    end
  end

  describe "transitions" do
    it "allows transition from pending to processing" do
      expect(state_machine.allowed_transitions).to include("processing")
    end

    it "performs transition from pending to processing" do
      expect(state_machine.current_state).to eq("pending")

      state_machine.transition_to!("processing")

      expect(state_machine.current_state).to eq("processing")
    end

    it "creates transition record in database" do
      expect {
        state_machine.transition_to!("processing")
      }.to change { content_archive.content_archive_transitions.count }.by(1)

      transition = content_archive.content_archive_transitions.last
      expect(transition.to_state).to eq("processing")
      expect(transition.most_recent).to be(true)
    end
  end

  describe "guards" do
    # Guards are tested by asserting that transition_to! raises Statesman::GuardFailedError
    #
    # Example:
    # it "prevents transition when guard condition fails" do
    #   # Setup condition that should make guard fail
    #   content_archive.update!(some_property: false)
    #
    #   expect { state_machine.transition_to!(:target_state) }
    #     .to raise_error(Statesman::GuardFailedError)
    # end
    #
    # it "allows transition when guard condition passes" do
    #   # Setup condition that should make guard pass
    #   content_archive.update!(some_property: true)
    #
    #   expect { state_machine.transition_to!(:target_state) }
    #     .to_not raise_error
    # end
  end

  describe "callbacks" do
    # Callbacks are tested by asserting observable effects of the transition
    #
    # Example for before_transition callback:
    # it "performs expected action before transition" do
    #   expect { state_machine.transition_to!(:target_state) }
    #     .to change { content_archive.reload.some_counter }.by(1)
    # end
    #
    # Example for after_transition callback:
    # it "sends notification after successful transition" do
    #   expect(NotificationService).to receive(:send_notification).with(content_archive)
    #   state_machine.transition_to!(:target_state)
    # end
  end
end
