module Api
  module V1
    class LinksController < ApplicationController
      include Saltbox::SortByColumns::Controller

      before_action :set_link, only: [:show, :update, :destroy]

      has_scope :search, only: [:index]

      # GET /api/v1/links
      def index
        links = apply_scopes(Link.all)
        @pagination, @links = pagy(links)
      end

      # GET /api/v1/links/:id
      def show
      end

      # GET /api/v1/links/by_url?url=...
      # Find a specific link by URL
      def by_url
        if params[:url].blank?
          render json: {error: "URL parameter is required"}, status: :bad_request
          return
        end

        @link = Link.find_by_url(params[:url])

        if @link
          render :show
        else
          head :not_found
        end
      end

      # POST /api/v1/links
      def create
        @link = Link.new(link_params)

        if @link.save
          render :show, status: :created
        else
          render json: {errors: @link.errors.full_messages}, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotUnique
        render json: {error: "A link with this URL already exists"}, status: :unprocessable_entity
      end

      # PATCH/PUT /api/v1/links/:id
      def update
        if @link.update(link_params)
          render :show
        else
          render json: {errors: @link.errors.full_messages}, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotUnique
        render json: {error: "A link with this URL already exists"}, status: :unprocessable_entity
      end

      # DELETE /api/v1/links/:id
      def destroy
        @link.destroy
        head :no_content
      end

      private

      def set_link
        @link = Link.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: {error: "Link not found"}, status: :not_found
      end

      def link_params
        params.expect(link: [:url, :note, {tag_names: []}])
      end
    end
  end
end
