# frozen_string_literal: true

class Api::V1::Statuses::FavouritesController < Api::BaseController
  include Authorization

  before_action -> { doorkeeper_authorize! :write, :'write:favourites' }
  before_action :require_user!

  def create
    @status = favourited_status
    render json: @status, serializer: REST::StatusStatSerializer
  end

  def destroy
    @status = requested_status
    @favourites_map = { @status.id => false }

    UnfavouriteWorker.new.perform(current_user.account_id, @status.id)

    render json: @status,
           serializer: REST::StatusStatSerializer,
           unfavourite: true,
           relationships: StatusRelationshipsPresenter.new([@status], current_user&.account_id, favourites_map: @favourites_map)
  end

  private

  def favourited_status
    service_result.status.reload
  end

  def service_result
    FavouriteService.new.call(current_user.account, requested_status, params[:reaction_id])
  end

  def requested_status
    Status.find(params[:status_id])
  end
end
