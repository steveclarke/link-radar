json.data do
  json.tag do
    json.partial! "api/v1/tags/tag", tag: @tag
  end

  if @links.present?
    json.recent_links do
      json.array! @links do |link|
        json.extract! link, :id, :url, :created_at
      end
    end
  end
end
