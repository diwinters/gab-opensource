# frozen_string_literal: true

class UpdateAccountService < BaseService
  def call(account, params, raise_error: false)
    was_locked    = account.locked
    update_method = raise_error ? :update! : :update

    note = params[:note]
    if !note.nil? && LinkBlock.block?(note)
      raise GabSocial::NotPermittedError, "Unable to update information"
    end
    
    account.send(update_method, params).tap do |ret|
      next unless ret

      authorize_all_follow_requests(account) if was_locked && !account.locked
      process_hashtags(account)
    end
  rescue GabSocial::DimensionsValidationError => de
    account.errors.add(:avatar, de.message)
    false
  end

  private

  def authorize_all_follow_requests(account)
    AuthorizeFollowWorker.push_bulk(FollowRequest.where(target_account: account).select(:account_id, :target_account_id)) do |req|
      [req.account_id, req.target_account_id]
    end
  end

  def process_hashtags(account)
    account.tags_as_strings = Extractor.extract_hashtags(account.note)
  end
end
