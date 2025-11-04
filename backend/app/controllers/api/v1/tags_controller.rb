module Api
  module V1
    class TagsController < ApplicationController
      include Saltbox::SortByColumns::Controller

      before_action :set_tag, only: [:show, :update, :destroy]

      # GET /api/v1/tags
      # Supports optional ?search= query parameter for autocomplete
      # Supports sorting via ?sort=column:direction
      # Examples:
      #   ?sort=name:asc
      #   ?sort=usage_count:desc
      #   ?sort=last_used_at:desc
      def index
        @tags = if params[:search].present?
          Tag.autocomplete(params[:search])
        else
          apply_scopes(Tag.all)
        end
      end

      # GET /api/v1/tags/:id
      def show
        @links = @tag.links.order(created_at: :desc).limit(10)
      end

      # POST /api/v1/tags
      def create
        @tag = Tag.new(tag_params)

        if @tag.save
          render :show, status: :created
        else
          render json: {
            errors: @tag.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/tags/:id
      def update
        if @tag.update(tag_params)
          render :show
        else
          render json: {
            errors: @tag.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/tags/:id
      def destroy
        @tag.destroy
        head :no_content
      end

      private

      def set_tag
        @tag = Tag.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: {error: "Tag not found"}, status: :not_found
      end

      def tag_params
        params.require(:tag).permit(:name, :description)
      end
    end
  end
end
