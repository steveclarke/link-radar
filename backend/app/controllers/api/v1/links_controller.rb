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
        raise ArgumentError, "URL parameter is required" if params[:url].blank?

        @link = Link.find_by_url!(params[:url])
        render :show
      end

      # POST /api/v1/links
      def create
        @link = Link.new(link_params)
        @link.save!
        render :show, status: :created
      end

      # PATCH/PUT /api/v1/links/:id
      def update
        @link.update!(link_params)
        render :show
      end

      # DELETE /api/v1/links/:id
      def destroy
        @link.destroy!
        head :no_content
      end

      private

      def set_link
        @link = Link.find(params[:id])
      end

      def link_params
        params.expect(link: [:url, :note, {tag_names: []}])
      end
    end
  end
end
