# frozen_string_literal: true

class PollExpirationNotifyWorker
  include Sidekiq::Worker

  sidekiq_options lock: :until_executed

  def perform(poll_id)
    poll = Poll.find_by(id: poll_id)
    return if poll.nil?
    
    # Notify poll owner and remote voters
    if poll.local?
      NotifyService.new.call(poll.account, poll)
    end

    # Notify local voters
    poll.votes.includes(:account).map(&:account).select(&:local?).each do |account|
      NotifyService.new.call(account, poll)
    end
  rescue ActiveRecord::RecordNotFound
    true
  end
end
