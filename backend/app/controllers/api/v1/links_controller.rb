module Api
  module V1
    class LinksController < ApplicationController
      include Saltbox::SortByColumns::Controller

      before_action :set_link, only: [:show, :update, :destroy]

      has_scope :search, only: [:index]

      # GET /api/v1/links
      # Supports sorting via ?sort=column:direction
      # Supports optional ?search= query parameter for full-text search
      # Examples:
      #   ?sort=title:asc
      #   ?sort=created_at:desc
      #   ?sort=title:asc,created_at:desc
      #   ?sort=c_tag_count:desc (sort by tag count)
      #   ?search=ruby programming
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

        normalized_query_url = normalize_url(params[:url])
        @link = Link.find_by(url: normalized_query_url)

        if @link
          render :show
        else
          head :not_found
        end
      end

      # POST /api/v1/links
      def create
        @link = Link.new(link_params)

        # Normalize url before saving
        begin
          @link.url = normalize_url(@link.url)
        rescue URI::InvalidURIError => e
          render json: {error: "Invalid URL: #{e.message}"}, status: :unprocessable_entity
          return
        end

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
        # If url is being updated, re-normalize
        if link_update_params[:url].present?
          begin
            normalized_url = normalize_url(link_update_params[:url])

            @link.assign_attributes(
              link_update_params.merge(url: normalized_url)
            )
          rescue URI::InvalidURIError => e
            render json: {error: "Invalid URL: #{e.message}"}, status: :unprocessable_entity
            return
          end
        else
          @link.assign_attributes(link_update_params)
        end

        if @link.save
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
        params.require(:link).permit(:url, :note, tag_names: [])
      end

      def link_update_params
        params.require(:link).permit(:url, :note, tag_names: [])
      end

      def normalize_url(url)
        uri = URI.parse(url)
        # Ensure scheme is present
        uri = URI.parse("http://#{url}") unless uri.scheme
        uri.to_s
      end
    end
  end
end
