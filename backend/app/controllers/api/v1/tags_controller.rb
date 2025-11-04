module Api
  module V1
    class TagsController < ApplicationController
      include Saltbox::SortByColumns::Controller

      before_action :set_tag, only: [:show, :update, :destroy]

      # GET /api/v1/tags
      # Supports optional ?search= query parameter for autocomplete/full-text search
      # When search is present, returns up to 20 results sorted by usage
      # When search is absent, returns all tags (can be sorted via ?sort=)
      # Examples:
      #   ?search=javascript          (returns top 20 by usage)
      #   ?sort=name:asc              (returns all, sorted by name)
      #   ?sort=usage_count:desc      (returns all, sorted by usage)
      has_scope :search, only: [:index] do |controller, scope, value|
        # Use autocomplete for search: limits to 20 results, sorts by usage
        # This is optimized for the extension's tag input dropdown
        scope.autocomplete(value)
      end

      def index
        @tags = apply_scopes(Tag.alphabetical)
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
