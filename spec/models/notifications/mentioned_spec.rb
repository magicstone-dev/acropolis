# frozen_string_literal: true

describe Notifications::Mentioned do
  class TestNotification < Notification
    include Notifications::Mentioned

    def self.filter_mentions(mentions, *)
      mentions
    end
  end

  describe ".notify" do
    let(:status_message) {
      FactoryGirl.create(:status_message, text: text_mentioning(remote_raphael, alice, bob, eve), author: eve.person)
    }

    it "calls filter_mentions on self" do
      expect(TestNotification).to receive(:filter_mentions).with(
        match_array(Mention.where(mentions_container: status_message, person: [alice, bob].map(&:person))),
        status_message,
        [alice.id, bob.id]
      ).and_return([])

      TestNotification.notify(status_message, [alice.id, bob.id])
    end

    it "creates notification for each mention" do
      [alice, bob].each do |recipient|
        expect(TestNotification).to receive(:create_notification).with(
          recipient,
          Mention.where(mentions_container: status_message, person: recipient.person_id).first,
          status_message.author
        )
      end

      TestNotification.notify(status_message, nil)
    end

    it "creates email notification for mention" do
      status_message = FactoryGirl.create(:status_message, text: text_mentioning(alice), author: eve.person)
      expect_any_instance_of(TestNotification).to receive(:email_the_user).with(
        Mention.where(mentions_container: status_message, person: alice.person_id).first,
        status_message.author
      )

      TestNotification.notify(status_message, nil)
    end

    it "doesn't create notification if it was filtered out by filter_mentions" do
      expect(TestNotification).to receive(:filter_mentions).and_return([])
      expect(TestNotification).not_to receive(:create_notification)
      TestNotification.notify(status_message, nil)
    end

    it "doesn't create notification if it already exists" do
      status_message = FactoryGirl.create(:status_message, text: text_mentioning(alice), author: eve.person)
      TestNotification.create(
        recipient: alice,
        target:    Mention.where(mentions_container: status_message, person: alice.person_id).first,
        actors:    [status_message.author]
      )

      expect(TestNotification).not_to receive(:create_notification)
      TestNotification.notify(status_message, nil)
    end

    it "doesn't create a notification for a mention in a comment of an already deleted post" do
      post = FactoryGirl.create(:status_message, public: true)
      comment = FactoryGirl.create(:comment, commentable: post, text: text_mentioning(alice))
      post.delete
      comment.reload

      expect {
        Notifications::MentionedInComment.notify(comment, [alice])
      }.to_not change(Notification, :count)
    end
  end
end
