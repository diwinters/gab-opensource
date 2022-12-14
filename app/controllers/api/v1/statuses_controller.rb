# frozen_string_literal: true

class Api::V1::StatusesController < Api::BaseController
  include Authorization

  before_action -> { authorize_if_got_token! :read, :'read:statuses' }, except: [:create, :update, :destroy]
  before_action -> { doorkeeper_authorize! :write, :'write:statuses' }, only:   [:create, :update, :destroy]
  before_action :require_user!, except:  [:show, :comments, :context, :card]
  before_action :set_status, only:       [:show, :comments, :context, :card, :update, :revisions]
  after_action :update_stream, only: [:create, :update]

  # This API was originally unlimited, pagination cannot be introduced without
  # breaking backwards-compatibility. Arbitrarily high number to cover most
  # conversations as quasi-unlimited, it would be too much work to render more
  # than this anyway
  # : TODO :
  CONTEXT_LIMIT = 512

  def show
    render json: @status, serializer: REST::StatusSerializer, relationships: StatusRelationshipsPresenter.new([@status], current_user&.account_id)
  end

  # all desendants
  def comments
    descendants_results = @status.descendants(CONTEXT_LIMIT, current_account, nil, nil)
    loaded_descendants  = cache_collection(descendants_results, Status)

    @context = Context.new(descendants: loaded_descendants)
    statuses = [@status] + @context.descendants

    render json: @context, serializer: REST::ContextSerializer, relationships: StatusRelationshipsPresenter.new(statuses, current_user&.account_id)
  end

  def context
    ancestors_results   = @status.in_reply_to_id.nil? ? [] : @status.ancestors(CONTEXT_LIMIT, current_account)
    descendants_results = @status.descendants(CONTEXT_LIMIT, current_account)
    loaded_ancestors    = cache_collection(ancestors_results, Status)
    loaded_descendants  = cache_collection(descendants_results, Status)

    @context = Context.new(ancestors: loaded_ancestors, descendants: loaded_descendants)
    statuses = [@status] + @context.ancestors + @context.descendants

    render json: @context, serializer: REST::ContextSerializer, relationships: StatusRelationshipsPresenter.new(statuses, current_user&.account_id)
  end

  def revisions
    @revisions = @status.revisions

    render json: @revisions, each_serializer: REST::StatusRevisionSerializer
  end

  def create
    log_request(:info)
    markdown = status_params[:markdown] unless status_params[:markdown] === status_params[:status]
    @status = PostStatusService.new.call(current_user.account,
                                         text: status_params[:status],
                                         markdown: markdown,
                                         autoJoinGroup: status_params[:autoJoinGroup],
                                         thread: status_params[:in_reply_to_id].blank? ? nil : Status.find(status_params[:in_reply_to_id]),
                                         media_ids: status_params[:media_ids],
                                         sensitive: status_params[:sensitive],
                                         spoiler_text: status_params[:spoiler_text],
                                         visibility: status_params[:visibility],
                                         scheduled_at: status_params[:scheduled_at],
                                         expires_at: status_params[:expires_at],
                                         application: doorkeeper_token.application,
                                         poll: status_params[:poll],
                                         group_id: status_params[:group_id],
                                         quote_of_id: status_params[:quote_of_id])

    render json: @status, serializer: @status.is_a?(ScheduledStatus) ? REST::ScheduledStatusSerializer : REST::StatusSerializer
  end

  def update
    log_request(:info)
    authorize @status, :update?
    markdown = status_params[:markdown] unless status_params[:markdown] === status_params[:status]
    @status = EditStatusService.new.call(@status,
                                         text: status_params[:status],
                                         markdown: markdown,
                                         media_ids: status_params[:media_ids],
                                         expires_at: status_params[:expires_at],
                                         sensitive: status_params[:sensitive],
                                         spoiler_text: status_params[:spoiler_text],
                                         visibility: status_params[:visibility],
                                         application: doorkeeper_token.application)

    render json: @status, serializer: REST::StatusSerializer
  end

  def destroy
    @status = Status.where(account_id: current_user.account).find(params[:id])
    authorize @status, :destroy?

    # StatusSimilarityService.new.clear(current_user.account)
    RemovalWorker.perform_async(@status.id)

    render json: @status, serializer: REST::StatusSerializer, source_requested: true
  end

  private

  def update_stream
    FeedManager.instance.push_to_home(@status.account, @status)
  end

  def set_status
    @status = Status.find(params[:id])
    authorize @status, :show?
  rescue GabSocial::NotPermittedError
    raise ActiveRecord::RecordNotFound
  end

  def status_params
    params.permit(
      :status,
      :markdown,
      :autoJoinGroup,
      :in_reply_to_id,
      :quote_of_id,
      :sensitive,
      :spoiler_text,
      :visibility,
      :scheduled_at,
      :expires_at,
      :group_id,
      media_ids: [],
      poll: [
        :expires_in,
        options: [],
      ],
    )
  end

  def pagination_params(core_params)
    params.slice(:limit).permit(:limit).merge(core_params)
  end
end
