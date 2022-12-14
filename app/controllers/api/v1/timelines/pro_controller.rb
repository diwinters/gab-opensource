# frozen_string_literal: true

class Api::V1::Timelines::ProController < Api::BaseController
  before_action :require_user!, only: [:show]
  after_action :insert_pagination_headers, unless: -> { @statuses.empty? }

  def show
    @statuses = load_statuses
    render json: @statuses, each_serializer: REST::StatusSerializer, relationships: StatusRelationshipsPresenter.new(@statuses, current_user&.account_id)
  end

  private

  def load_statuses
    ActiveRecord::Base.connected_to(role: :reading) do
      cache_collection pro_statuses, Status
    end
  end

  def pro_statuses
    statuses = pro_timeline_statuses.paginate_by_id(
      limit_param(DEFAULT_STATUSES_LIMIT),
      params_slice(:max_id, :since_id, :min_id)
    )

    if truthy_param?(:only_media)
      # `SELECT DISTINCT id, updated_at` is too slow, so pluck ids at first, and then select id, updated_at with ids.
      status_ids = statuses.joins(:media_attachments).distinct(:id).pluck(:id)
      statuses = statuses.where(id: status_ids)
    end

    statuses = statuses.uniq { |s| s.account_id }

    statuses
  end

  def pro_timeline_statuses
    Status.as_pro_timeline(current_account)
  end

  def insert_pagination_headers
    set_pagination_headers(next_path, prev_path)
  end

  def pagination_params(core_params)
    params.slice(:limit, :only_media).permit(:limit, :only_media).merge(core_params)
  end

  def next_path
    api_v1_timelines_pro_url pagination_params(max_id: pagination_max_id)
  end

  def prev_path
    api_v1_timelines_pro_url pagination_params(min_id: pagination_since_id)
  end

  def pagination_max_id
    @statuses.last.id
  end

  def pagination_since_id
    @statuses.first.id
  end
end
