# frozen_string_literal: true

class REST::StatusSerializer < ActiveModel::Serializer
  attributes :id, :created_at, :revised_at, :in_reply_to_id, :in_reply_to_account_id,
             :sensitive, :spoiler_text, :visibility, :language, :uri,
             :url, :direct_replies_count, :replies_count, :reblogs_count, :pinnable, :pinnable_by_group,
             :favourites_count, :quote_of_id, :expires_at, :has_quote, :bookmark_collection_id,
             :quotes_count, :reaction_id, :reactions_counts

  attribute :favourited, if: :current_user?
  attribute :reblogged, if: :current_user?
  attribute :muted, if: :current_user?

  attribute :content, unless: :source_requested?
  attribute :rich_content, unless: :source_requested?
  attribute :plain_markdown, unless: :source_requested?
  attribute :text, if: :source_requested?

  belongs_to :reblog, serializer: REST::StatusSerializer
  belongs_to :quote, serializer: REST::StatusSerializer
  belongs_to :account, serializer: REST::AccountSerializer
  belongs_to :group, serializer: REST::GroupSerializer

  has_many :media_attachments, serializer: REST::MediaAttachmentSerializer
  has_many :ordered_mentions, key: :mentions
  has_many :tags
  has_many :emojis, serializer: REST::CustomEmojiSerializer

  has_one :preview_card, key: :card, serializer: REST::PreviewCardSerializer
  has_one :preloadable_poll, key: :poll, serializer: REST::PollSerializer

  def id
    object.id.to_s
  end

  def direct_replies_count
    if instance_options && instance_options[:relationships]
      instance_options[:relationships].direct_replies_count_map[object.id] || 0
    else
      object.direct_replies_count
    end
  end

  def quotes_count
    if instance_options && instance_options[:relationships]
      instance_options[:relationships].quotes_count_map[object.id] || 0
    else
      object.quotes_count
    end
  end

  def replies_count
    object.replies_count
  end

  def in_reply_to_id
    object.in_reply_to_id&.to_s
  end

  def in_reply_to_account_id
    object.in_reply_to_account_id&.to_s
  end

  def quote_of_id
    object.quote_of_id&.to_s
  end

  def current_user?
    !current_user.nil?
  end

  def visibility
    # This visibility is masked behind "private"
    # to avoid API changes because there are no
    # UX differences
    if object.limited_visibility?
      'private'
    else
      object.visibility
    end
  end

  def uri
    "/#{object.account.username}/posts/#{object.id}"
  end

  def content
    blocked_by_status_owner = false
    if instance_options && instance_options[:relationships]
      blocked_by_status_owner = instance_options[:relationships].blocked_by_map[object.account_id] || false
    end

    if blocked_by_status_owner
      '[HIDDEN – USER BLOCKS YOU]'
    else
      Formatter.instance.format(object).strip
    end
  end

  def rich_content
    blocked_by_status_owner = false
    if instance_options && instance_options[:relationships]
      blocked_by_status_owner = instance_options[:relationships].blocked_by_map[object.account_id] || false
    end

    if blocked_by_status_owner
      '[HIDDEN – USER BLOCKS YOU]'
    else
      Formatter.instance.format(object, use_markdown: true).strip
    end
  end

  def plain_markdown
    blocked_by_status_owner = false
    if instance_options && instance_options[:relationships]
      blocked_by_status_owner = instance_options[:relationships].blocked_by_map[object.account_id] || false
    end

    if blocked_by_status_owner
      '[HIDDEN – USER BLOCKS YOU]'
    else
      object.markdown
    end
  end

  def url
    TagManager.instance.url_for(object)
  end

  def favourited
    if instance_options && instance_options[:relationships]
      !!instance_options[:relationships].favourites_map[object.id] || false
    else
      current_user.account.favourited?(object)
    end
  end

  def muted
    if instance_options && instance_options[:relationships]
      instance_options[:relationships].mutes_map[object.conversation_id] || false
    else
      current_user.account.muting_conversation?(object.conversation)
    end
  end

  def favourites_count
    object.favourites_count
  end

  def reaction_id
    if instance_options && instance_options[:relationships]
      instance_options[:relationships].favourites_map[object.id] || nil
    else
      current_user&.account&.reaction_id(object)
    end
  end

  def reblogged
    if instance_options && instance_options[:relationships]
      instance_options[:relationships].reblogs_map[object.id] || false
    else
      current_user.account.reblogged?(object)
    end
  end

  def bookmarked
    return
  end

  def pinned
    return
  end

  PINNABLE_VISIBILITIES = %w(public unlisted).freeze
  def pinnable
    current_user? &&
      current_user.account_id == object.account_id &&
      !object.reblog? &&
      PINNABLE_VISIBILITIES.include?(object.visibility)
  end

  def pinned_by_group
    return
  end

  def pinnable_by_group
    object.group_id?
  end

  def source_requested?
    instance_options[:source_requested]
  end

  def ordered_mentions
    object.active_mentions.to_a.sort_by(&:id)
  end

  def bookmark_collection_id
    instance_options[:bookmark_collection_id]
  end

  class ApplicationSerializer < ActiveModel::Serializer
    attributes :name, :website
  end

  class MentionSerializer < ActiveModel::Serializer
    attributes :id, :username, :url, :acct

    def id
      object.account_id.to_s
    end

    def username
      object.account_username
    end

    def url
      TagManager.instance.url_for(object.account)
    end

    def acct
      object.account_acct
    end
  end

  class TagSerializer < ActiveModel::Serializer
    include RoutingHelper

    attributes :name, :url

    def url
      "/tags/#{object.name}"
    end
  end
end
