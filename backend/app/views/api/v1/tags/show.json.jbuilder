json.partial! "api/v1/tags/tag", tag: @tag

if @links.present?
  json.recent_links do
    json.array! @links do |link|
      json.extract! link, :id, :url, :title, :created_at
    end
  end
end
