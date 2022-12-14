# frozen_string_literal: true

class InitialStateSerializer < ActiveModel::Serializer
  attributes :meta, :compose, :accounts,
             :media_attachments, :settings

  has_one :push_subscription, serializer: REST::WebPushSubscriptionSerializer

  def meta
    store = {
      streaming_api_base_url: Rails.configuration.x.streaming_api_base_url,
      access_token: object.token,
      locale: I18n.locale,
      domain: Rails.configuration.x.local_domain,
      version: GabSocial::Version.to_s,
      report_categories: Report.categories.keys,
    }

    if object.current_account
      store[:username]           = object.current_account.username
      store[:me]                 = object.current_account.id.to_s
      store[:unfollow_modal]     = object.current_account.user.setting_unfollow_modal
      store[:boost_modal]        = object.current_account.user.setting_boost_modal
      store[:show_videos]        = object.current_account.user.setting_show_videos
      store[:show_suggested_users]  = object.current_account.user.setting_show_suggested_users
      store[:show_groups]        = object.current_account.user.setting_show_groups
      store[:delete_modal]       = object.current_account.user.setting_delete_modal
      store[:auto_play_gif]      = object.current_account.user.setting_auto_play_gif
      store[:display_media]      = object.current_account.user.setting_display_media
      store[:expand_spoilers]    = object.current_account.user.setting_expand_spoilers
      store[:pro_wants_ads]      = object.current_account.user.setting_pro_wants_ads
      store[:is_staff]           = object.current_account.user.staff?
      store[:unread_count]       = unread_count object.current_account
      store[:last_read_notification_id] = object.current_account.user.last_read_notification
      store[:is_first_session]   = is_first_session object.current_account
      store[:email_confirmed]    = object.current_account.user.confirmed?
      store[:email]              = object.current_account.user.confirmed? ? '[hidden]' : object.current_account.user.email
      store[:active_reactions]   = ReactionType.serialized_active_reactions
      store[:all_reactions]      = ReactionType.serialized_all_reactions
    else
      store[:all_reactions]      = ReactionType.serialized_all_reactions
    end

    store
  end

  def compose
    store = {}

    if object.current_account
      store[:me]                = object.current_account.id.to_s
      store[:default_privacy]   = object.current_account.user.setting_default_privacy
      store[:default_sensitive] = object.current_account.user.setting_default_sensitive
    end

    store[:text] = object.text if object.text

    store
  end

  def accounts
    store = {}
    store[object.current_account.id.to_s] = ActiveModelSerializers::SerializableResource.new(object.current_account, serializer: REST::AccountSerializer) if object.current_account
    store
  end

  def media_attachments
    { accept_content_types: MediaAttachment.supported_file_extensions + MediaAttachment.supported_mime_types }
  end

  private

  def unread_count(account)
    account.unread_count
  end

  def instance_presenter
    @instance_presenter ||= InstancePresenter.new
  end

  def is_first_session(account)
    object.current_account.user.sign_in_count === 1
  end

end
